require "securerandom"

require_relative "../lib/facet_test.rb"
require_relative "../lib/src/streaming/nil_stream.rb"


class ParentTest
    @@classVal = "CV Demo"
    @@regexDemo = /something.*/

    attr_accessor :child

    def initialize(someVal,child)
        @someVal = someVal
        @child = child

        def makeChild(sv)
            @child = ChildTest.new(sv)
            return @child
        end
    end
end

class ChildTest
    def initialize(someVal)
        @someVal = someVal
    end
end

test "Facet" do |spr|
    opt = FacetOptions.new
    opt.streamer = NilStream.new
    failTest = Frame.new("Fail Tests",opt)

    spr.sub "clauses" do |f|
        f.facet "no exception" do |test|
            test.that {true} 
            failTest.facet "explicit no exception fail" do |ft|
                ft.that {unnamedFunctionGeneratingAnException}
            end
            test.that {failTest.tests["explicit no exception fail"].getResult} .is {:exception}
        end

        f.facet "is match" do |test|
            test.that {true} .is {true}
            failTest.facet "is match fail" do |ft|
                ft.that {true} .is {false}
            end
            test.that {failTest.tests["is match fail"].getResult} .is {:fail}
        end

        f.facet "not match" do |test|
            test.that {true} .not .is {false}
            failTest.facet "not match fail" do |ft|
                ft.that {true} .not .is {true}
            end
            test.that {failTest.tests["not match fail"].getResult} .is {:fail}
        end

        f.facet "and match" do |test|
            test.that {true} .is {true} .and .that {false} .is {false}
            failTest.facet "and match fail" do |ft|
                ft.that {true} .is {true} .and .is {false}
            end
            test.that {failTest.tests["and match fail"].getResult} .is {:fail}
        end

        f.facet "or match" do |test|
            test.that {true} .is {true} .or .is {false}
            failTest.facet "or match fail" do |ft|
                ft.that {true} .is {false} .and .is {false}
            end
            test.that {failTest.tests["or match fail"].getResult} .is {:fail}
        end

        f.facet "xor match" do |test|
            test.that {true} .is {true} .xor .is {false}
            test.that {true} .not do |c|
                c.is {true} .xor .is {true}
            end
            failTest.facet "xor match fail" do |ft|
                ft.that {true} .is {true} .xor .is {true}
            end
            test.that {failTest.tests["xor match fail"].getResult} .is {:fail}
        end

        f.facet "not and or xor match" do |test|
            test.that {true} .is {true} .and .is{true} .xor .is {false} .not {false} .or {true}
        end

        f.facet "like match" do |test|   
            childA = ChildTest.new(1)
            childB = ChildTest.new(1)
            childC = ChildTest.new(2)
            
            parentA = ParentTest.new(1,childA)
            parentB = ParentTest.new(1,childB)
            parentC = ParentTest.new(1,childC)
            parentD = ParentTest.new(2,childC)
            parentE = ParentTest.new(1,childC)

            test.that {parentA} .like {parentB}
            test.that {parentA} .not .like {parentC}
            test.that {parentA} .not .like {parentD}
            test.that {parentE} .not .like {parentA}
        end

        f.facet "err match" do |t|
            t.err {notAFunction} .isType {NameError}
            t.err {true} .is {nil}
        end

        f.facet "isType match" do |t|
            t.that {true} .isType {TrueClass}
            failTest.facet "isType match fail" do |ft|
                ft.that {true} .isType {FalseClass}
            end
            t.that {failTest.tests["isType match fail"].getResult} .is {:fail}
        end


        f.facet "pick match" do |t|
            myArr = [1,2,3]
            t.that {myArr} .pick {|v|v.count} .is {3} .and .is {myArr}
        end
    end

    spr.sub "types" do |f|
        f.facet "string passes" do |t|
            t.that {"Some string"} .is {"Some string"}
        end

        f.facet "Symbol passes" do |t|
            t.that {:something} .is {:something}
        end

        f.facet "TrueClass passes" do |t|
            t.that {true} .is {true}
        end

        f.facet "FalseClass passes" do |t|
            t.that {false} .is {false}
        end

        f.facet "NilClass passes" do |t|
            t.that {nil} .is {nil}
        end

        f.facet "Numeric passes" do |t|
            t.that {55.5} .is {55.5}
        end

        f.facet "Regexp passes" do |t|
            t.that {/^start/} .is {/^start/}
        end

        f.facet "Array passes" do |t|
            t.that {[1,2,3]} .is {[1,2,3]}
        end

        f.facet "Hash passes" do |t|
            t.that {{:a=>1,:b=>2}} .is {{:a=>1,:b=>2}}
        end

        f.facet "nested array passes" do |t|
            t.that {[[1,2,3],[4,5,6]]} .is {[[1,2,3],[4,5,6]]}
            t.that {[{:a=>2,:b=>5}]} .is {[{:a=>2,:b=>5}]}
        end

        f.facet "nested hash passes" do |t|
            t.that do {:a=>{:a=>1,:b=>2}} end .is do {:a=>{:a=>1,:b=>2}} end
            t.that do {:a=>{:a=>[1,2,3]}} end .is  do {:a=>{:a=>[1,2,3]}} end
        end

        f.facet "complex class passes" do |t|
            childA = ChildTest.new(1)
            childB = ChildTest.new(1)
            parentA = ParentTest.new(1,childA)
            parentB = ParentTest.new(1,childB)
        
            t.that {parentA} .like {parentB}
        end

        f.facet "recursive class passes" do |t|
            curseA = ParentTest.new("Recursive parent",nil)
            curseB = ParentTest.new("Recursive parent",nil)
            curseC = ParentTest.new("Middle Recursive",curseA)
            curseA.child = curseC
            curseB.child = curseC
            t.that {curseA} .like {curseB}
        end

        f.facet "class with data is not like class without data" do |test|
            class Ehash
                attr_accessor :hVals
            end

            emptyA = Ehash.new
            emptyB = Ehash.new
            fullA = Ehash.new
            fullA.hVals = {:a=>1,:b=>2,:c=>"fish"}
            fullB = Ehash.new
            fullB.hVals = {:a=>1,:d=>3}
            fullC = Ehash.new
            fullC.hVals = {:a=>1,:b=>2,:c=>"fish"}

            test.that {emptyA} .like {emptyB} .and .not .like {fullA}
            test.that {fullA} .like {fullC} .and .not .like {fullB}
        end

        f.facet "class data is picked appropriately" do |test|
            par = ParentTest.new(10,nil)
            test.that {par} .pick {|tp|tp.makeChild(55)} .like {ChildTest.new(55)}
        end
    end
end

test "Kitchen Sink" do |f|
    ks = KitchenSink.new
    ks.data :one, true,false
    ks.data :two, true,false
    ks.data :cond, 0,1
    ks.result(:res).on(:one,:two).when(:cond=>0).set(
        [true,true]=>true,
        [true,false]=>false,
        [false,true]=>false,
        [false,false]=>true
    )

    totalCount = 0
    resultCount = 0
    ks.wash do |data,testCount|
        if data[:res] != nil
            f.facet "KitchenSink round: #{testCount}" do |t|
                t.that {data[:one] == data[:two]} .is {data[:res]} 
            end
            resultCount += 1
        end
        totalCount = testCount
    end
    f.facet "KitchenSink rounds" do |t|
        t.that {totalCount} .is {8}
        t.that {resultCount} .is {4}
    end
end

test "MuckyPup" do |f|
    f.facet "mucky generates each type" do |t|
        t.that {MuckyPup.genAlphaNumeric(10,10)} .isType {String} .and .pick {|tp|tp.length} .is {10}
        t.that {MuckyPup.genBool} .is {true} .or .is {false}
        t.that {MuckyPup.genByteString(10,10)} .isType {String} .and .pick {|tp|tp.length} .is {10}
        t.that {MuckyPup.genHexString(10,10)} .isType {String} .and .pick {|tp|tp.length} .is {20}
        t.that {MuckyPup.genUrlSafeString(10,10)} .isType {String} .and .pick {|tp|tp.length} .is {20}
        t.that {MuckyPup.genInt(0,100)} .isType {Integer} .and .pick{|tp|tp < 100} .is {true} .and .pick {|tp|tp >= 0} .is {true}
        t.that {MuckyPup.genFloat(0,100)} .isType {Float} .and .pick{|tp|tp < 100} .is {true} .and .pick {|tp|tp >= 0} .is {true}
        t.that {MuckyPup.genSymbol} .isType {Symbol}
    end

    def genVals(pup,times)
        types = {:string=>0,:float=>0,:integer=>0,:bool=>0,:symbol=>0}
        times.times do 
            val = pup.genVal.class
            if val == String then types[:string] += 1 end
            if val == Float then types[:float] += 1 end
            if val == Integer then types[:integer] += 1 end
            if val == Symbol then types[:symbol] += 1 end
            if val == TrueClass then types[:bool] += 1 end
            if val == FalseClass then types[:bool] += 1 end
        end
        return types
    end

    f.facet "mucky generates types based on weight" do |t|
        pup = MuckyPup.new(allTypes:true)
        disMax = 1100
        disMin = 900
        disStrMax = 4400
        disStrMin = 3600
        
        genVals(pup,8000).each do |k,v|
            if k == :string
                t.that("distribution, basic, string types") {v} .that {v < disStrMax} .is {true} .and .that {v > disStrMin} .is {true}
            else
                t.that("distribution, basic, #{k} type") {v} .that {v < disMax} .is {true} .and .that {v > disMin} .is {true}
            end
        end

        ks = KitchenSink.new
        ks.data :type, *MuckyPup.getTypes
        ks.wash do |data|
            pup = MuckyPup.new(allTypes: true)
            pup.setWeight(data[:type],0)
            genVals(pup,7000).each do |k,v|
                mul = 1
                if k == :string 
                    mul = 4
                    if(
                        data[:type] == :alphaNumericString or 
                        data[:type] == :hexString or
                        data[:type] == :byteString or
                        data[:type] == :urlSafeString
                    )
                        mul = 3
                    end
                elsif k == data[:type] then mul = 0 end
                t.that {v} .that {mul} .that {v <= disMax * mul} .is {true} .and .that {v >= disMin * mul} .is {true}
            end
        end
    end

    f.facet "mucky generates an array with types based on weight" do |t|
        types = {:string=>0,:float=>0,:integer=>0,:bool=>0,:symbol=>0}
        pup = MuckyPup.new(allTypes:true)
        valArray = pup.genValArray(8000)
        
        valArray.each do |val|
            val = val.class
            if val == String then types[:string] += 1 end
            if val == Float then types[:float] += 1 end
            if val == Integer then types[:integer] += 1 end
            if val == Symbol then types[:symbol] += 1 end
            if val == TrueClass then types[:bool] += 1 end
            if val == FalseClass then types[:bool] += 1 end
        end
        
        disMax = 1100
        disMin = 900
        disStrMax = 4400
        disStrMin = 3600
        types.each do |k,v|
            if k == :string
                t.that("distribution, basic, string types") {v} .that {v < disStrMax} .is {true} .and .that {v > disStrMin} .is {true}
            else
                t.that("distribution, basic, #{k} type") {v} .that {v < disMax} .is {true} .and .that {v > disMin} .is {true}
            end
        end
    end
end
