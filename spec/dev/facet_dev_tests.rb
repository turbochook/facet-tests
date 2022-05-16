require_relative "../../lib/facet_test.rb"
require_relative "../../lib/src/streaming/nil_stream.rb"

test "Facet" do |frame|
    frame.facet "Test that a frame will stop testing after the first fail." do |test|
        opt = FacetOptions.new
        opt.streamer = NilStream.new
        opt.stopOnFail = true
        failTest = Frame.new("Fail Tests",opt)

        failTest.facet "Fail Test One" do |t|
            t.that {true} .is {false}
        end
        failTest.facet "Fail Test Two" do |t|
            t.that {true} .is {false}
        end

        test.that {failTest.tests} .pick {|ftr|ftr.count} .is {1} .and .pick {|ftr|ftr["Fail Test One"]} .not .is {nil}
    end
end