#
# Small POD class that stores the result of a Facet Test suite.
#
class FacetSummary
    # @return [Integer] number of Facets that passed.
    attr_reader :passed
    # @return [Integer] number of Facets that failed or had exceptions.
    attr_reader :failed
    # @return [Integer] number of Facets that weren't fully implemented.
    attr_reader :notImplemented
    # @return [Integer] number of Facets that ran (passed + failed).
    attr_reader :facetsRan
    # @return [Integer] number of Facets that were defined (facetsRan + notImplemented).
    attr_reader :totalFacets

    #
    # Takes the result of a frame and fills out the summary of results.
    #
    # @param [Hash] facetResults to summarize. Form is "Facet Description"=>{FacetResult}
    #
    def initialize(facetResults)
        @passed = facetResults.count{|k,v|v.status == :pass}
        @failed = facetResults.count{|k,v|v.status == :fail or v.status == :exception}
        @notImplemented = facetResults.count{|k,v|v.status == :notImplemented}

        @facetsRan = @passed + @failed
        @totalFacets = facetsRan + @notImplemented
    end

    #
    # Overloaded + to allow merging summaries.
    #
    # @param [FacetSummary] rhs
    #
    # @return [<Type>] <description>
    #
    def +(rhs)
        @passed += rhs.passed
        @failed += rhs.failed
        @notImplemented += rhs.notImplemented
        @facetsRan += rhs.facetsRan
        @totalFacets += rhs.totalFacets

        return self
    end
end