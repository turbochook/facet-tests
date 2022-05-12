require_relative "plaintext_filter.rb"

#
# Class that does not provide any output of test data/results.
#
class NilStream
    #
    # Builds our new streamer.
    #
    def initialize
    end
  
    def stream(data,breakStream=false)
    end

    #
    # Function to create a streamer-appropriate break. In this case just adds an empty line.
    #
    def streamBreak
    end
end