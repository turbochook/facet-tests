require_relative "streaming/console_stream.rb"

#
# State machine for the options to modify the behaviour
# of the testing suite. Also defines defaults.
#
class FacetOptions
    # @return [String] what set of characters we should use for a single 'indent'.
    #   Defaults to: '\s\s'.
    attr_accessor :indentString
    # @return [Hash] defines whether we should show a result for an individual facet.
    #   true/false for tests that :pass, :fail, :exception or :notIimplemented.
    #   Defaults to: :pass=>false,:fail=>true,:exception=>true,:notImplemented=>true
    attr_reader :showFacets
    # @return [Hash] defines whether we should show a result for an individual facet test.
    #   true/false for tests that :pass, :fail, :exception or :notIimplemented.
    #   Defaults to: :pass=>false,:fail=>true,:exception=>true,:notImplemented=>false
    attr_accessor :showTests
    # @return [Hash] defines whether we should show the list of operations and the 
    #   result for a given test (eg that: pass, is: pass).
    #   true/false for tests that :pass, :fail, :exception or :notIimplemented.
    #   Defaults to: :pass=>false,:fail=>true,:exception=>true,:notImplemented=>false
    attr_reader :showOperators
    # @return [Hash] defines whether we should show the returned data for operators
    #   (:set and :match).
    #   true/false for tests that :pass, :fail, :exception or :notIimplemented.
    #   Defaults to: :pass=>false,:fail=>false,:exception=>true,:notImplemented=>false
    attr_reader :showOperatorData
    # @return [Hash] codes for the console to control the colour of :fail, :pass, :alert, 
    #   :neutral and :exception messages.
    #   Defaults to: :fail=>31, :pass=>32, :alert=>33, :neutral=>29, :exception=>31.
    attr_accessor :colourCodes
    # @return [Object] the filter we're passing our results through. Defaults to {PlaintextFilter}
    attr_accessor :filter
    # @return [Boolean] true if we're doing any kind of operation tracing. Disabled automatically
    #   based on the various show options, and used to try and save space if not needed.
    attr_reader :tracingEnabled
    # @return [Object] the object that is responsible for doing something with our results, eg
    #   displaying to the console, saving to a file, etc. 
    #   Defaults to: {ConsoleStream}.
    attr_accessor :streamer
    # @return [String] used for a simple string match to determine if we should run a particular
    #   facet test.
    attr_accessor :facetFilter
    # @return [Array[Symbol]] used to check if we should run a facet based on the associated tags. 
    attr_reader :facetTagFilter
    # @return [String] used for a simple string match to determine if we should run a particular
    #   frame
    attr_accessor :frameFilter
    # @return [Array[Symbol]] used to check if we should run a test within facet based on the associated tags. 
    attr_reader :testTagFilter
    # @return [Boolean] determines if we show a diff bbetween expected and actual on failed tests.
    #   Defaults to: true.
    attr_reader :showDiff
    # @return [Integer] the maximum number of characters we would like to show on a line.
    #   Defaults to: 160.
    attr_reader :lineCharLength
    # @return [Boolean] Controls whether we will continue our test suite after a fail/exception
    attr_accessor :stopOnFail

    #
    # Builds a new FacetOptions setting all our defaults.
    #
    def initialize
        @indentString = "\s\s"
        @showFacets = {:pass=>false,:fail=>true,:exception=>true,:notImplemented=>true}
        @showTests = {:pass=>false,:fail=>true,:exception=>true,:notImplemented=>false}
        @showOperators = {:pass=>false,:fail=>true,:exception=>true,:notImplemented=>false}
        @showOperatorData = {:pass=>false,:fail=>false,:exception=>true,:notImplemented=>false,:set=>true,:diff=>true}
        @colourCodes = {}
        @colourCodes[:fail] = 31
        @colourCodes[:pass] = 32
        @colourCodes[:alert] = 33
        @colourCodes[:neutral] = 29
        @colourCodes[:exception] = 31
        @filter = PlaintextFilter.new(self)
        if @showOperators.detect{|_tk,tv|tv == true} == nil then @tracingEnabled = false
        else @tracingEnabled = true end
        @streamer = ConsoleStream.new(self)
        @fullOperationTrace = false
        @facetFilter=nil
        @facetTagFilter=nil
        @testTagFilter=nil
        @showDiff = true
        @lineCharLength = 160
        @frameFilter = nil
        @stopOnFail = false
    end

    #
    # Function to determine if we should run a facet based on the description and tags.
    #
    # @param [String|nil] facetDescription user provided description of the facet.
    # @param [Array|nil] tags filtering which Facets are run.
    #
    # @return [Boolean] true if the facet should run, false if not.
    #
    def runFacet?(facetDescription,tags=nil)
        if @facetFilter and facetDescription and !facetDescription.include?(@facetFilter)
            return false
        end
        if @facetTagFilter and (@facetTagFilter.difference(tags).count == @facetTagFilter.count)
            return false
        end

        return true
    end

    #
    # Function to determine if we should run a frame of facets based on the description and tags.
    #
    # @param [String|nil] frameDescription description of the test.
    # @param [Array|nil] frameTags filtering which tests are run.
    #
    # @return [Boolean] true if the test should run, false if not.
    #
    def runFrame?(frameDescription,frameTags=nil)
        if @frameFilter and !frameDescription.include?(@frameFilter)
            return false
        end

        return true
    end

    #
    # Update the operator data trace to true/false for a particular condition.
    #
    # @param [Symbol] condition :pass, :fail, :notImplemented or :exception if we should update.
    # @param [Boolean] show true/false to show/hide data for that condition.
    #
    def setOperatorDataTrace(condition,show)
        @showOperatorData[condition] = show
        updateTracing
    end

    #
    # Update the operator trace to true/false for a particular condition.
    #
    # @param [Symbol] condition :pass, :fail, :notImplemented or :exception if we should update.
    # @param [Boolean] show true/false to show/hide data for that condition.
    #
    def setOperatorTrace(condition,show)
        @showOperators[condition] = show
        updateTracing
    end

    #
    # Update the test trace to true/false for a particular condition.
    #
    # @param [Symbol] condition :pass, :fail, :notImplemented or :exception if we should update.
    # @param [Boolean] show true/false to show/hide data for that condition.
    #
    def setTestTrace(condition,show)
        @showTests[condition] = show
        updateTracing
    end

    #
    # Update the facet trace to true/false for a particular condition.
    #
    # @param [Symbol] condition :pass, :fail, :notImplemented or :exception if we should update.
    # @param [Boolean] show true/false to show/hide data for that condition.
    #
    def setFacetTrace(condition,show)
        @showFacets[condition] = show
        updateTracing
    end

    def updateTracing
        @tracingEnabled = true
        if !@showFacets.values.include?(true) then @tracingEnabled = false end
        if !@showTests.values.include?(true) then @tracingEnabled = false end
        if !@showOperators.values.include?(true) then @tracingEnabled = false end
        if !@showOperatorData.values.include?(true) then @tracingEnabled = false end
    end
end