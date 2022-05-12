require "set"

#
# Class to facilitate the creation of bulk tests based on a set of data. 
# Comes with three main features:
#   - Automatic calculation of all combinations of values to be tested
#   - Ability to define static expected results
#   - Ability to define custom functions to produce test data
#
# KitchenSink allows the user to quickly define the data for bulk tests
# and expose that for testing. The custom functionality allows the user
# to quickly and easily define functions for the purpose of fuzzing.
#
# The #wash function yields a hash with our test data, covering all 
# combinations of data provided. We can then define tests within a block
# using the hash to easily define a large number of tests.
#
class KitchenSink
    # @!attribute [rw] dishes
    #   @return [Array] stores our dishes - test data.
    # @!attribute [rw] defined
    #   @return [Set] used to ensure name uniqueness for #set, #gen and #result
    # @!attribute [rw] results
    #   @return [Array] stores our statically defined expected results for our test data
    
    #
    # Builds a new KitchenSink, setting our initial values.
    #
    def initialize
        @dishes = []
        @defined = Set.new
        @results = []
    end

    #
    # Define a data-set for us to test. Provides a name that we hook into 
    # when defining our tests and all possible values we would like to test in a 
    # splatted array.
    #
    # @param [Symbol|String] name we wish to link the data to. Must be unique.
    # @param [Object] values the values that will be accessible under the name for our tests.
    #   
    # @raise [ArgumentError] when the test name has already been defined.
    #
    def data(name,*values)
        if @defined.include? name then raise ArgumentError.new ":#{name} has already been defined." end
        @defined << name
        @dishes << DefinedDish.new(name,values)
    end

    #
    # Define a function that will create test data when requested.
    #
    # @param [String|Symbol] name we wish to linke the data to. Must be unique.
    # @param [Integer] count number of times we wish to run this function. Will be combined with 
    #   other data (eg data :a, 1,2 and gen :b, 2 will run 4 tests)
    # @param [Boolean] cache it is common for the same data to be called multiple times (eg [a,b] [c,d]
    #   will result in combinations ac,ad,bc,bd). Caching will prevent the function being called multiple
    #   times for the 'same' data request. Disable means it is called every time the data is requested.
    # @param [Proc] block to call to generate data. Can either have 0 or 1 argument - the proc is passed
    #   the index of the test (0..(count - 1)).
    #
    # @raise [ArgumentError] when the test name has already been defined.
    #
    def gen(name,count,cache=true,&block)
        if @defined.include? name then raise ArgumentError.new ":#{name} has already been defined." end
        if !block_given? then raise ArgumentError.new "Expecting block defining generated data, none provided." end
        @dishes << GeneratedDish.new(name,cache,count,block)
    end

    #
    # Groups multiple data definitions into a single count such that we don't test each possible
    # combination of grouped items. If we only have a grouped test, then we will only run the 
    # count parameter number of tests. If we have other tests, then regardless of the number of
    # items in the group, we will only use the count parameter to define how many combinations to
    # test.
    #
    # ```
    #   ks = KitchenSink.new
    #   ks.group(3) do |g|
    #       ks.data :lhs, 1,2,3
    #       ks.data :rhs, 4,5,6
    #   end
    #   # At this point, we will only be running three tests: 1,4 then 2,5 then 3,6
    #   ks.data :op, :is, :not
    #   # We will now be running 6 tests (not the 18 if we weren't using the group).
    #   # The tests will be: (1,4,:is), (1,4,:not), (2,5,:is), (2,5,:not), (3,6,:is), (3,6,:not)
    # ```
    #
    # @param [Integer] count the number of times to get data in the group sets.
    #
    # @yield the group to allow the consumer to define their data.
    #
    def group(count)
        @dishes << KitchenSinkGroup.new(count,@defined)
        yield @dishes[-1]
    end

    #
    # Wash the dishes. Calculates all combinations of the data defined, then
    # fetches the data one combination at a time and yields to the consumer 
    # for use.
    #
    # @yieldparam [Hash] fillSink a hash that contains the test data in 
    #   a name=>item (name being the name defined by the consumer in the #set or #gen 
    #   function)
    # @yieldparam [Integer] testCount the count of the current test, starting
    # at 1.
    #
    def wash
        if @dishes.count > 0
            whatDishesFeelsLike = (0...@dishes[0].count).to_a
            dishExplosion = []
            
            @dishes[1..-1].each do |key|
                dishExplosion << (0...(key.count)).to_a
            end
            whatDishesFeelsLike = whatDishesFeelsLike.product(*dishExplosion)
            whatDishesFeelsLike.each_with_index do |dataIndices,testCount|
                fillSink = {}
                dataIndices.each_with_index do |dIdx,dishIdx|
                   fillSink.merge!(@dishes[dishIdx].dump(dIdx))
                end
                @results.each do |r| r.setResult(fillSink) end
                yield fillSink, (testCount + 1)
            end
        end
    end

    #
    # Used to allow the user to define a set of expected results. Generates a {#KitchenSinkResult}
    # that allows the consumer to a key->value pair to the data yielded in #chuck as a way of
    # statically checking that tested data produces an expected result.
    #
    # Usage is like: ks.result(:name).when(:condition=>true).on(:a,:b).set([true,true]=>true,[true,false]=>false)
    # :name defines the name the result will be stored under in the yielded hash.
    # when allows us to define conditions for generating the result (name == value).
    # on is where we define the names that we are defining the result for.
    # set allows us to define a result for a set of values, in the form of Array[name1,name2]=>value
    #   the order of the array should be the same as the parameter order in .on.
    #
    # @param [String|Symbol] name we wish to link the data to. Must be unique.
    #
    # @return [KitchenSinkResult] allows us to define our expected result. Usually chained.
    #
    # @raise [ArgumentError] when the test name has already been defined.
    #
    def result(name)
        if @defined.include?(name) then raise ArgumentError.new ":#{name} has already been defined." end
        @results << KitchenSinkResult.new(name)
        return @results[-1]
    end
end

#
# Group together a set of values such that they are generated x count, instead of 
# value name count * value name count.
#
class KitchenSinkGroup
    # @!attribute [rw] dishes
    #   @return [Array] stores our dishes - test data.
    # @!attribute [rw] defined
    #   @return [Set] used to ensure name uniqueness for #set and #gen

    # @return [Integer] number of times we should run the data defined in this group.
    attr_reader :count

    #
    # Builds a new KitchenSinkGroup
    #
    # @param [Integer] count number of times we should run the data defined in this group.
    # @param [<Type>] defined used to ensure name uniqueness for #set and #gen
    #
    def initialize(count,defined)
        @count = count
        @defined = defined
        @dishes = []
    end

    #
    # Define a data-set for us to test. Provides a name that we hook into 
    # when defining our tests and all possible values we would like to test in a 
    # splatted array.
    #
    # @param [Symbol|String] name we wish to link the data to. Must be unique.
    # @param [Object] values the values that will be accessible under the name for our tests.
    #
    # @raise [ArgumentError] when the number of values doesn't match #count or the test name has
    #   already been defined.
    #
    def data(name, *values)
        if values.count != @count
            raise ArgumentError.new "Group expecting #{@count} values but #{values.count} provided"
        end
        if @defined.include?(name) then raise ArgumentError.new ":#{name} has already been defined." end
        @dishes << DefinedDish.new(name,values)
    end
    #
    # Define a function that will create test data when requested. We don't need to define a count
    # here because count is defined at the group level.
    #
    # @param [String|Symbol] name we wish to linke the data to. Must be unique.
    # @param [Boolean] cache it is common for the same data to be called multiple times (eg [a,b] [c,d]
    #   will result in combinations ac,ad,bc,bd). Caching will prevent the function being called multiple
    #   times for the 'same' data request. Disable means it is called every time the data is requested.
    # @param [Proc] block to call to generate data. Can either have 0 or 1 argument - the proc is passed
    #   the index of the test (0..(count - 1)).
    #
    # @raise [ArgumentError] when the test name has already been defined.
    #
    def gen(name,cache=true,&block)
        if @defined.include?(name) then raise ArgumentError.new ":#{name} has already been defined." end
        if !block_given? then raise ArgumentError.new "Expecting block defining generated data, none provided." end
        @dishes << GeneratedDish.new(name,cache,@count,block)
    end

    #
    # Gets the data for a specified test run for all grouped gen and set data.
    #
    # @param [Integer] idx of the test run for this group.
    #
    # @return [Hash] name=>data based on the name defined in the set/gen functions.
    #
    def dump(idx)
        dishDump = {}
        @dishes.each do |dish|
            dishDump.merge! dish.dump(idx)
        end
        
        return dishDump
    end
end

#
# Used to store a pre-defined set of results for a given set of inputs.
# Allows the consumer to define what result they're expecting for a given
# set of data inputs.
#
class KitchenSinkResult
    # @!attribute [r] name
    #   @return [Symbol|String] the name we should store the expected result under.
    # @!attribute [rw] conditions
    #   @return [Hash] the conditions that must be met for us to consider this result. 
    #       Format is name=>data.
    # @!attribute [rw] filters
    #   @return [Array] The test data names we'll be looking at to find the appropriately defined result.
    # @!attribute [rw] set
    #   @return [Hash] the conditions that must be met for us to consider this result.
    #       Format is [v1,v2...]=>result. The key values must be ordered in the same order as the filters array.
    #       Checking is done using == between the data[name] and the key array item that corresponds.

    #
    # Builds a new KitchenSinkResult
    #
    # @param [Symbol|String] name we wish to link the result to. Must be unique.
    #
    def initialize(name)
        @name = name
        @conditions = {}
        @filters = []
        @set = {}
    end

    #
    # Used to define some expected data before we provide this 
    # result. EG .on(:someVal=>1) means we will only search for
    # a result here when :someVal is returning 1 as defined by
    # a set or gen function elsewhere.
    #
    # @param [Hash] conditions in the form of name=>data where name has been defined in the set
    #   or gen function.
    #
    # @return [KitchenSinkResult] to allow chaining.
    #
    def when(**conditions)
        @conditions = conditions
        return self
    end

    #
    # Used to define which names we're matching data to define a result for.
    #
    # @param [String|Symbol] filters should match names defined in set or gen functions.
    #
    # @return [KitchenSinkResult] to allow chaining.
    #
    def on(*filters)
        @filters = filters
        return self
    end

    #
    # Defines a result according to the data of the names we are checking as defined in #on.
    #
    # @param [Hash] results in the form of an array of values, order should match #on.
    #   eg .on(:lhs,:rhs).set([true,false]=>true) means that we're setting our result value
    #   to true when :lhs is true and :rhs is false. We use == to check conditions.
    #
    # @return [KitchenSinkResult] to allow chaining.
    #
    def set(**results)
        @results = results
        return self
    end

    #
    # Call this with a data object. If we can find a matching result based on our
    # conditions then the data key is added with the appropriate data, otherwise
    # no action is taken.
    #
    # @param [Hash] data with our name=>value for a single test run. Will have
    #   the result name added if we can find result data for this run, otherwise no change.
    #
    def setResult(data)
        @conditions.each do |name,value|
            if data[name] != value then return nil end
        end
        @results.each do |filter,value|
            filterMatch = true
            filter.each_with_index do |fv,idx|
                if data[@filters[idx]] != fv
                    filterMatch = false
                    break
                end
            end
            if filterMatch
                data[@name] = value
                break
            end
        end
    end
end

#
# Used to flatten statically defined values with dynamically defined values.
#
class DefinedDish
    # @return [Integer] the number of values that we will test.
    attr_reader :count

    #
    # Creates a new DefinedDish.
    #
    # @param [Symbol|String] name we wish to link the result to. Must be unique.
    # @param [Array] values that we wish to test.
    #
    def initialize(name,values)
        @name = name
        @values = values
        @count = @values.count
    end

    #
    # Returns the test value for a specified test index.
    #
    # @param [Integer] idx the index for this test.
    #
    # @return [Hash] with the dataName=>data
    #
    def dump(idx)
        return {@name=>@values[idx]}
    end
end

#
# Used to flatten dynamically defined values with statically defined values
#
class GeneratedDish
    # @return [Integer] the number of values that we will test.
    attr_reader :count

    #
    # Creates a new GeneratedDish
    #
    # @param [Symbol|String] name we wish to link the result to. Must be unique.
    # @param [<Type>] cache used to determine if we store our result for a particular
    #   test index, or run the function every time #dump is called.
    # @param [Integer] count the number of values that we will test.
    # @param [Proc] generator that creates our test value.
    #
    def initialize(name,cache,count,generator)
        @name = name
        @generator = generator
        @count = count
        if cache then @cache = {} end
    end

    #
    # Returns the test value for a specified test index.
    #
    # @param [Integer] idx of the test.
    #
    # @return [Hash] in dataName=>value format.
    #
    def dump(idx)
        dishDump = {@name=>nil}
        if @cache and @cache[idx]
            dishDump[@name] = @cache[idx]
        else            
            dishDump[@name] = @generator.call(idx)
            if @cache then @cache[idx] = dishDump[@name] end
        end

        return dishDump
    end
end