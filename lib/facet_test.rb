require 'optparse'

require_relative "kitchen_sink.rb"
require_relative "mucky_pup.rb"
require_relative "src/frame.rb"
require_relative "src/facet_options.rb"

#
# Entry Function to run a test suite. Allows quick definition of
# unit tests using a test |frame| block format. Output is handled
# by the frame.
#
# @param [String] desc describes what we're testing.
#
# @yieldreturn [Frame] allows the consumer to define their tests.
#
def test(desc)
    options = @facetOptions
    if !options then options = FacetOptions.new end
    if options.runFrame?(desc,tags=nil)
        testObj = Frame.new(desc,options)
        yield testObj
        if testObj.summarize.totalFacets > 0
            options.streamer.stream(testObj.summarize)
            options.streamer.streamBreak
        end
    end
end

#
# Helper function to parse the flags passed in to determine what level of
# tracing will be displayed. Works by yielding a true or false value for each
# possible trace option.
#
# @param [String] options passed by the user.
#
# @yieldreturn [Symbol] the condition that we're determining whether to show or not.
# @yieldreturn [Boolean] whether we should show the linked condition or not.
#
def setTrace(options,setInPlay=false,diffInPlay=false)
    if options.class == String
        if /p/ =~ options then yield :pass, true
        else yield :pass, false end
        if /f/ =~ options then yield :fail, true
        else yield :fail, false end
        if /e/ =~  options then yield :exception, true
        else yield :exception, false end
        if /n/ =~ options then yield :notImplemented, true
        else yield :notImplemented, false end
        if setInPlay and /s/ =~ options then yield :set, true
        elsif setInPlay then yield :set, false end
        if diffInPlay and /d/ =~ options then yield :diff, true
        elsif diffInPlay then yield :diff, false end
    else
        yield :pass, false
        yield :fail, false
        yield :exception, false
        yield :notImplemented, false
        if setInPlay then yield :set, false end
        if diffInPlay then yield :diff, false end
    end
end


cmds={}

# Build an option parser to allow us to insert command line parsing into our test
# scripts.
OptionParser.new do |opts|
    opts.banner = "Run your test suite/s."

    opts.on("-e","--frame=FRAME","Run a frame whose description includes the input text.")
    opts.on("-f","--facet=FACET","Run a facet whose description includes the input text.")
    opts.on(
        "-d",
        "--operatorTraceData [flags]",
        "Conditions under which the data recorded for operations -rpfen. " +
        "Options are p=pass,f=fail,e=exception and n=notImplemented. Operation " +
        "data will show for operations that will show according to the -o flag."
    )
    opts.on(
        "-o",
        "--operatorTrace [flags]",
        "Conditions under which a trace of operations should show in the form -rpfen. " +
        "Options are p=pass,f=fail,e=exception and n=notImplemented. Any options not present will " +
        "not have the test trace shown. Default is fail and exception. This setting will only affect " +
        "tests that will show according to the -t flag."
    )
    opts.on(
        "-t",
        "--testTrace [flags]",
        "Conditions under which a trace of tests should show in the form -rpfen. " +
        "Options are p=pass,f=fail,e=exception and n=notImplemented. Any options not present will " +
        "not have the test shown. Default is fail and exception. This setting will only affect " +
        "facets that will show according to the -r option."
    )
    opts.on(
        "-r",
        "--facetTrace [flags]",
        "Conditions under which a facet should show in the form -rpfen. " +
        "Options are p=pass,f=fail,e=exception and n=notImplemented. Any options not present will " +
        "not have the facet shown. Default is fail and exception."
    )
    opts.on(
        "-A",
        "--traceAll",
        "Show all traces for the test regardless of condition. Equivalent to passing pfen to -t, -o, -d and -r"
    )
end.parse!(into:cmds)

@facetOptions = FacetOptions.new

if cmds.has_key?(:traceAll) 
    cmds[:operatorTrace] = "pfen"
    cmds[:testTrace] = "pfen"
    cmds[:facetTrace] = "pfen"
    cmds[:operatorTraceData] = "pfensd"
end

@facetOptions.facetFilter = cmds[:facet]
@facetOptions.frameFilter = cmds[:frame]

if cmds.has_key? :operatorTrace
    setTrace(cmds[:operatorTrace]) do |result,show|
        @facetOptions.setOperatorTrace(result,show)
    end
end

if cmds.has_key? :testTrace
    setTrace(cmds[:testTrace]) do |result,show|
        @facetOptions.setTestTrace(result,show)
    end
end

if cmds.has_key? :facetTrace
    setTrace(cmds[:facetTrace]) do |result,show|
        @facetOptions.setFacetTrace(result,show)
    end
end

if cmds.has_key? :operatorTraceData
    setTrace(cmds[:operatorTraceData],true,true) do |result,show|
        @facetOptions.setOperatorDataTrace(result,show)
    end
end

@facetOptions.streamer.streamBreak