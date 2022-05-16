require_relative "../../lib/facet_test.rb"
require_relative "../../lib/src/streaming/nil_stream.rb"

# These tests are designed to ensure that tests are being printed correctly
# console commands are working. As such, these tests may potentially fail.

require_relative "../../lib/facet_test.rb"
require_relative "../../lib/src/streaming/nil_stream.rb"

test "Console" do |frame|
    frame.facet "fail one (use with the -S flag to see if only one fail is shown)" do |test|
        test.that {true} .is {false}
    end

    frame.facet "fail two" do |test|
        test.that {true} .is {false}
    end
end