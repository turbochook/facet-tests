require "pp"

require_relative "../facet_summary.rb"

#
# Takes output of the testing framework and provides a plaintext 
# result with indents.
#
class PlaintextFilter
    # @!attribute [r] options
    #   @return [FacetOptions] options for the test run.
    
    #
    # Build a new Plaintext Filter
    #
    # @param [FacetOptions] options that define the behaviour of the filter.
    #
    def initialize(options)
        @options = options
    end

    #
    # Take some test data and return it as a plaintext string.
    #
    # @param [String|FacetResult|FacetSummary] data to transform. Strings are returned as is, Facet Results
    #   and FacetSummarys are parsed into strings.
    #
    # @yieldreturn [Hash] :text, :indent (quantity) and a :type for a streamer to display.
    #
    # @raise [StandardError] when an invalid type (not string or FacetResult or FacetSummary) is passed for processing.
    #
    def transform(data)
        if data.class == String 
            yield ({:text=>data,:indent=>0,:type=>:neutral})
        elsif data.class == FacetSummary
            summaryColour = :pass
            if data.failed == data.totalFacets then summaryColour = :fail
            elsif data.passed != data.totalFacets then summaryColour = :neutral end
            yield ({:text=>"#{data.passed}/#{data.totalFacets} Facets Passed",:indent=>1,:type=>summaryColour})
    
            if data.passed != data.totalFacets
                if data.passed > 0
                    yield ({:text=>"Passed Facets: #{data.passed}",:indent=>2,:type=>:pass})
                end
                if data.failed > 0
                    yield ({:text=>"Failed Facets: #{data.failed}",:indent=>2,:type=>:fail})
                end
                if data.notImplemented > 0 
                    yield ({:text=>"Facets not Implemented: #{data.notImplemented}",:indent=>2,:type=>:neutral})
                end
            end
        elsif data.class == FacetResult
            result = data.getResult
            if !@options.showFacets[result] then return nil end
            case result
            when :pass
                yield ({:text=>"Pass: Facet '#{data.facetName}'",:indent=>1,:type=>:pass})
            when :fail
                yield ({:text=>"Fail: Facet '#{data.facetName}'",:indent=>1,:type=>:fail})
            when :exception
                yield ({:text=>"Exceptions: Facet '#{data.facetName}'",:indent=>1,:type=>:fail})
            when :notImplemented
                yield ({:text=>"Unimplemented: Facet '#{data.facetName}'",:indent=>1,:type=>:alert})
            else
                yield ({:text=>"Unimplemented Tests: Facet '#{data.facetName}'",:indent=>1,:type=>:alert})
            end 
            
            data.testResults.each do |testName,testResult|
                if @options.showTests[testResult.status] 
                    printTest(testName,testResult){|tData| yield tData}
                end
            end
        else
            raise StandardError.new "Invalid type passed for streaming: #{data.class}"
        end
    end

    #
    # Helper function that summarizes a Test Result and the clause trace where relevant.
    # Used to display (when appropriate) the result of the test and the trace of the 
    # tests that were run.
    #
    # @param [String] testName of the TestResult
    # @param [TestResult] testResult that we're displaying the result of.
    #
    # @yieldreturn [Hash] :text, an :indent (quantity) and a :type for a streamer to display.
    #
    def printTest(testName,testResult)
        case testResult.status 
        when :pass
            yield ({:text=>"Pass: Test '#{testName}'",:indent=>2,:type=>:pass})
        when :fail
            yield ({:text=>"Fail: Test '#{testName}'",:indent=>2,:type=>:fail})
        when :exception
            yield ({:text=>"Exception: Test '#{testName}'",:indent=>2,:type=>:fail})
        when :notImplemented
            yield ({:text=>"Not Implemented: Test '#{testName}'",:indent=>2,:type=>:alert})
        end
        if @options.showOperators[testResult.status]
            printOperationTrace(testResult) {|out|yield out}
        end
    end

    #
    # Function that will conver the clause trace for a TestResult into a string. Will also show the diff result
    # for failed tests.
    #
    # @param [TestResult] testResult we're displaying the clause trace for.
    #
    # @yieldreturn [Hash] :text, an :indent (quantity) and a :type for a streamer to display.
    #
    def printOperationTrace(testResult)
        indentLvl = 3
        thatData = nil
        testResult.operationTrace.each do |op|
            if op.operationGroup == :set
                thatData = op.data
            end
            case op.operation
            when :blockStart then indentLvl += 1
            when :blockEnd then indentLvl -= 1
            else
                yield ({:text=>"#{op.operation}: #{op.getResult}",:indent=>indentLvl,:type=>op.getResult})
                nestedIndentLvl = indentLvl + 1
                if(
                    op.data != nil and
                    (
                        @options.showOperatorData[op.getResult] or
                        (op.operationGroup == :set and @options.showOperatorData[:set])
                    )
                )   
                    if op.getResult == :exception
                        if(op.data.kind_of?(Exception))
                            yield({:text=>"#{op.data.message}",:indent=>nestedIndentLvl,:type=>:exception})
                            yield({:text=>"",:indent=>nestedIndentLvl,:type=>:neutral})
                            op.data.backtrace.each do |tm|
                                yield({:text=>tm,:indent=>nestedIndentLvl,:type=>:exception})
                            end
                        else yield({:text=>"Exception: #{op.data.pretty_inspect}",:indent=>indentLvl,:type=>:exception}) end
                    else
                        printSnapshot(op.data) do |snapLine,lvl|
                            yield({:text=>snapLine,:indent=>nestedIndentLvl+lvl,:type=>op.getResult})
                        end
                    end
                end
                if @options.showOperatorData[:diff] and op.getResult == :fail and op.operationGroup == :match
                    diffResult = FacetSnapshot.diff(thatData,op.data)
                    if diffResult
                        yield ({:text=>"Difference:",:indent=>indentLvl,:type=>:neutral})
                        printSnapshot(diffResult) do |snapLine,lvl|
                            yield({:text=>snapLine,:indent=>nestedIndentLvl+lvl,:type=>:fail})
                        end
                    else 
                        yield ({:text=>"that == #{op.operation}",:indent=>nestedIndentLvl,:type=>:fail})
                    end
                end
            end
        end
    end

    #
    # Helper function that goes through a FacetSnapshot and converts to plain text.
    # Displays stored data, ignoring FacetDiff and FacetDiffList classes.
    #
    # @param [FacetSnapshot] snap to stringify.
    # @param [Integer] lvl depth we're currently at, used to determine indent.
    #
    # @yieldreturn [String] text to display.
    # @yieldreturn [Integer] lvl of indent to apply.
    #
    def printSnapshot(snap,lvl=0)
        if snap.simpleType
            text = nil
            dataText = snap.data.to_s
            if snap.dataType == String
                dataText = "\"#{dataText}\""
            end
            if snap.name then text = "#{snap.name}: #{dataText}"
            else text = dataText end
            yield text, lvl
        else
            head = nil
            if snap.dataType != FacetDiff and snap.dataType != FacetDiffList
                head = "#{snap.dataType} #{snap.id}"
            end
            if snap.dataType == HashTuple 
                head = "Hash Tuple"
            elsif snap.name and head then head = "#{snap.name}: #{head}"
            elsif snap.name then head = snap.name end
            
            if head then yield head, lvl end
            lvl += 1

            snap.data.each do |_name,data| 
                printSnapshot(data,lvl){|dst,childLvl|yield dst,childLvl}
            end
        end
    end
end