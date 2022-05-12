require_relative "plaintext_filter.rb"

#
# Class that takes the results of the test and displays them in the console.
#
class ConsoleStream
    # @!attribute [r] options
    #   @return [FacetOptions] options for the test run.

    #
    # Builds our new streamer.
    #
    # @param [FacetOptions] options for this test run.
    #
    def initialize(options)
        @options = options
    end

    #
    # Takes some text and applies the colour code
    #
    # @param [String] text to colourize.
    # @param [Integer] code that defines the colour.
    #
    # @return [String] coded string to update the text colour.
    #
    def colourize(text,code)
        return "\e[#{code}m#{text}\e[0m"
    end

    #
    # Takes the data, passes through our linked filter and then prints the result to the console.
    # Will ensure that newlines are all indented and limits line length where options are set appropriately.
    #
    # @param [String,FacetResult,FacetSummary] data to stream. Data is sent to the filter stored in {#options}
    #   for processing.
    #
    def stream(data,breakStream=false)
        breakNeeded = false
        @options.filter.transform(data) do |line|
            breakNeeded = true
            line[:text].split(/\n/).each do |lineText| # print each line seperately to maintain indent over multiline
                if !@options.lineCharLength or @options.lineCharLength == 0
                    puts colourize("#{@options.indentString * line[:indent]}#{lineText}",@options.colourCodes[line[:type]])
                else # Limit the lines to the max charlength and break overflow to a new line maintaining indent.
                    truncLength = @options.lineCharLength - (@options.indentString.length * line[:indent])
                    if truncLength < 20 then truncLength = 20 end
                    lineText.scan(/.{1,#{truncLength}}/).each do |lineTextTrunc|
                        puts colourize("#{@options.indentString * line[:indent]}#{lineTextTrunc}",@options.colourCodes[line[:type]])
                    end
                end
            end
        end
        if breakStream and breakNeeded then streamBreak end
    end

    #
    # Function to create a streamer-appropriate break. In this case just adds an empty line.
    #
    def streamBreak
        puts ""
    end
end