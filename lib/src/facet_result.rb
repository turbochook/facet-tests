require_relative "test_result.rb"

#
# Stores the result of a Facet Level test, which includes one or more sub-tests.
#
class FacetResult
    # @return [Hash] stores the results of the various tests that make up the Facet test.
    #   results are stored in name=>result format. 
    attr_reader :testResults
    # @return [String] Name of the Facet test.
    attr_reader :facetName
    # @return [Symbol] overall status of the Facet test, :pass, :fail, :exception, :notImplemented
    attr_reader :status

    #
    # Creates a new result for a new Facet test.
    #
    # @param [String] facetName name of the Facet test.
    #
    def initialize(facetName)
        @facetName = facetName
        @testResults = {}
        @status = :notImplemented
    end

    #
    # Builds a new test for the Facet.
    #
    # @param [String] testName of the test. If nil is provided, the test is named
    #   with a number based on the count of registered tests, plus 1 - ie tests are
    #   named in sequence starting from 1.
    #
    # @return [TestResult] the result object we should complete for the newly registered test.
    #
    # @raise StandardError when we provide a testName that has already been registered.
    #
    def registerTest(testName = nil)
        if !testName then testName = @testResults.count + 1 end
        if @testResults[testName] != nil 
            raise StandardError.new "Trying to register Facet test under a name that already exists: #{testName}"
        end
        @testResults[testName] = TestResult.new
        
        return @testResults[testName]
    end

    #
    # Gets the overall result of the test. 
    #
    # @return [Symbol] returns :pass, :fail or :notImplemented based on the result of the {#testResults}
    #
    def getResult
        if @status == :exception then return :exception end
        if @testResults.count == 0 
            @status = :notImplemented
            return :notImplemented 
        elsif @testResults.detect{|k,v|v.status != :pass} == nil 
            @status = :pass
            return :pass 
        elsif @testResults.detect{|k,v|v.status != :notImplemented} == nil
            @status = :notImplemented
            return :notImplemented  
        else
            @status = :fail
            return :fail 
        end
    end

    #
    # If an exception is generated during the testing process, we should call this function
    # so that the result is updated to the exception type.
    #
    def exceptional!
        @status = :exception
    end

    def update!
        @testResults.each do |_n,tr|  
            tr.updateStatus
        end
    end
end
