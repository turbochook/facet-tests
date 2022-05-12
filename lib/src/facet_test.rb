require_relative "facet_clause.rb"

#
# Class used to kick off the definition for a particular test, storing the result
# on completion.
#
class FacetTest
    attr_reader :result

    #
    # Builds a new FacetTest. Expects a result stored in a Frame to 
    # fill out via the clause chain.
    #
    # @param [FacetResult] result the overall FacetResult that we'll be storing our
    #   results in.
    # @param [FacetOptions] options for the test run.
    #
    def initialize(result,options)
        @result = result
        @options = options
    end

    #
    # Runs a test for the facet.
    #
    # @param [String] testName optional name for the facet-level test, otherwise
    #   tests are numbered starting from 1.
    # @param [Proc] block used for the starting 'that' call to define what we're testing.
    #
    # @return [FacetClause] to allow the consumer to define the test.
    #
    def that(testName=nil,&block)
        testResult = @result.registerTest(testName)
        
        clause = FacetClause.new(testResult,@options)
        clause.that(&block)

        return clause
    end

    #
    # Runs a test for the facet. Provides entry with the err method.
    #
    # @param [String] testName optional name for the facet-level test, otherwise
    #   tests are numbered starting from 1.
    # @param [Proc] block used for the starting 'that' call to define what we're testing.
    #
    # @return [FacetClause] to allow the consumer to define the test.
    #
    def err(testName=nil,&block)
        testResult = @result.registerTest(testName)
        
        clause = FacetClause.new(testResult,@options)
        clause.err(&block)

        return clause
    end
end