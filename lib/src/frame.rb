require_relative "facet_result.rb"
require_relative "facet_clause.rb"
require_relative "facet_test.rb"
require_relative "facet_summary.rb"

#
# The Frame defines a scope of tests for a particular suite.
# It is basically just a grouping for a set of related tests.
#
class Frame
    # @!attribute [r] options
    #   @return [FacetOptions] options for the Frame.

    # @!attribute [wr] frameIntroduced
    #   @return [Boolean] true if the frame has already displayed the testing banner.

    # @!attribute [wr] description
    #   @return [String] description of the frame.

    # @!attribute [wr] subFrames
    #   @return [Array] store of the subframes that have been defined by this frame

    # @return [Hash] Stores the results for all the Facets in the frame in the format
    #   "Facet description"=>{FacetResult}
    attr_reader :tests

    #
    # Create our frame.
    #
    # @param [String] desc brief description of what's being tested.
    # @param [FacetOptions] options to control behaviour of testing.
    #
    def initialize(desc,options)
        @options = options
        @tests = {}
        @frameIntroduced = false
        @description = desc
        @subFrames = []
    end

    #
    # Creates a sub frame that can be defined using the yielded block.
    #
    # @param [String] desc describes the sub-frame
    #
    # @yieldreturn [Frame] to allow the consumer to define their sub-frame.
    #
    def sub(desc)
        @subFrames << Frame.new(desc,@options)
        yield @subFrames[-1]
    end

    #
    # Defines a Facet - a group of tests designed to prove a particular functionality (facet) of
    # the code. Each Facet consists of a number of tests, made up of a number of clauses, bound
    # to one description.
    #
    # @param [String] desc describes what we're checking with the tests.
    #
    # @yieldreturn [FacetTest] to allow the consumer to define their tests.
    #
    def facet(desc)
        if @tests[desc] then raise StandardError.new "Facet already defined: #{desc}" end
        if @options.runFacet?(desc)
            if !@frameIntroduced 
                @options.streamer.stream("Testing #{@description}")
                @options.streamer.streamBreak
                @frameIntroduced = true
            end
            @tests[desc] = FacetResult.new(desc)
            if block_given?
                begin 
                    yield (FacetTest.new(@tests[desc],@options))
                rescue ClauseError
                    @tests[desc].exceptional!
                end
            end

            @options.streamer.stream(@tests[desc],true)
        end
    end

    #
    # Returns a summary of the performed tests.
    #
    # @return [FacetSummary] 
    #
    def summarize
        summary = FacetSummary.new(@tests)
        @subFrames.each do |sf|
            summary += sf.summarize
        end

        return summary
    end
end
