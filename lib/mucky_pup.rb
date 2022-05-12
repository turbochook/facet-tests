require "securerandom"
require "set"

#
# A class designed to ease the creation of random values for testing.
# Basic idea is that a MuckyPup is set up with a number of types with
# weights (defaulted to 1). This allows the generation of a stream of 
# values, not necessarily of the same type, to assist with testing.
#
class MuckyPup   
    # !@attribute types [r]
    #   @return [Set] the types that this object will generate.
    # !@attribute weights [rw]
    #   @return [Hash] of types=>weight, how often this type should be generated
    #       as opposed to other types.
    # !@attribute totalWeight [rw]
    #   @return [Integer] the total weight of all included types.
    
    # @return [Integer] The minimum (incl) our random integers are allowed to be.
    attr_accessor :intMin
    # @return [Integer] The maximum (incl) our random integers are allowed to be.
    attr_accessor :intMax
    # @return [Number] The minimum (incl) our random floats are allowed to be.
    attr_accessor :floatMin
    # @return [Number] The maximum (excl) our random floats are allowed to be.
    attr_accessor :floatMax
    # @return [Integer] Maximum number of characters (incl) our random string may have.
    attr_accessor :alphaNumericMaxChars
    # @return [Integer] Maximum number of characters (incl) our random string may have.
    attr_accessor :byteStringMaxChars
    # @return [Integer] Maximum number of characters (incl) our random string may have.
    attr_accessor :hexStringMaxChars
    # @return [Integer] Maximum number of characters (incl) our random string may have.
    attr_accessor :urlSafeStringMaxChars
    # @return [Integer] Minimum number of characters (incl) our random string may have.
    attr_accessor :alphaNumericMinChars
    # @return [Integer] Minimum number of characters (incl) our random string may have.
    attr_accessor :byteStringMinChars
    # @return [Integer] Minimum number of characters (incl) our random string may have.
    attr_accessor :hexStringMinChars
    # @return [Integer] Minimum number of characters (incl) our random string may have.
    attr_accessor :urlSafeStringMinChars
    
    #
    # Builds a new MuckyPup. Allows us to set what types this instance will generate. 
    # Only one of exclude, picktypes, allTypes or all default is allowed.
    #
    # @param excludeTypes [Set] will make the MuckyPup only generate types NOT in this set.
    # @param pickTypes [Set] will make the MuckyPup only generate types in this set.
    # @param allTypes [Boolean] will make the MuckyPup generate all types (excludes)
    #   byteString, hexString and urlSafeString by default.
    #
    def initialize(
        excludeTypes:Set[],
        pickTypes:Set[],
        allTypes:false
    )
        if allTypes
            @types = MuckyPup.getTypes
        elsif pickTypes.count > 0
            @types = pickTypes
        elsif excludeTypes.count > 0
            @types = MuckyPup.getTypes.reject{|t|excludeTypes.include?(t)}
        else
            @types = MuckyPup.getTypes.reject do |t|
                t == :byteString or
                t == :hexString or
                t == :urlSafeString
            end
        end

        @intMin = -0xFFFFFFF
        @intMax = 0xFFFFFFF
        @floatMin = -0xFFFFFF 
        @floatMax = 0xFFFFFF
        @alphaNumericMaxChars = 1024
        @byteStringMaxChars = 1024
        @hexStringMaxChars = 1024
        @urlSafeStringMaxChars = 1024
        @alphaNumericMinChars = 0
        @byteStringMinChars = 0
        @hexStringMinChars = 0
        @urlSafeStringMinChars = 0
        @weights = {}
        @types.each do |t|
            @weights[t] = 1
        end
        @totalWeight = @weights.values.sum
    end

    #
    # Creates a new random value, type randomly decided based on available types and weights.
    #
    # @return [String|Integer|Float|Boolean|Symbol] randomly generated value.
    #
    def genVal
        weightType = SecureRandom.random_number(1..@totalWeight)
        typeToGen = nil
        @weights.each do |k,v|
            weightType -= v
            if weightType <= 0
                typeToGen = k
                break
            end
        end
        case typeToGen
        when :alphaNumericString then return MuckyPup.genAlphaNumeric(@alphaNumericMinChars,@alphaNumericMaxChars)
        when :byteString then return MuckyPup.genByteString(@byteStringMinChars,@byteStringMaxChars)
        when :hexString then return MuckyPup.genHexString(@hexStringMinChars,@hexStringMaxChars)
        when :urlSafeString then return MuckyPup.genUrlSafeString(@urlSafeStringMinChars,@urlSafeStringMaxChars)
        when :symbol then return MuckyPup.genSymbol
        when :integer then return MuckyPup.genInt(@intMin,@intMax)
        when :float then return MuckyPup.genFloat(@floatMin,@floatMax)
        when :bool then return MuckyPup.genBool
        end

        return nil
    end

    #
    # Generates an array of random values, types and distribution determined by the set types and weights.
    #
    # @param [Integer] length number of items in generated array (values generated).
    #
    # @return [<Type>] <description>
    #
    def genValArray(length)
        return length.times.map {genVal}
    end
    
    #
    # Update the weighted value of a type. Note, can only update types that have been set 
    # during the initialization stage of the object. 
    #
    # @param [Symbol] type that we want to update.
    # @param [Integer] weight the new weight to set the type to.
    #
    # @raise [ArgumentError] when a type that was not set at initialization is presented as the type.
    #
    def setWeight(type,weight)
        if !@types.include?(type) 
            throw ArgumentError.new "Type #{type} is not included in this MuckyPup instance."
        end
        @weights[type] = weight
        @totalWeight = @weights.values.sum
    end

    #
    # Create a random alphanumeric string (aA-zZ0-9) of a length between min and max (incl).
    #
    # @param [Integer] min length, inclusive.
    # @param [Integer] max length, inclusive.
    #
    # @return [String]
    #
    def self.genAlphaNumeric(min,max)
        len = genInt(min,max)
        if len == 0 then return "" 
        else
            return SecureRandom.alphanumeric(len)
        end
    end

    #
    # Create a random string of arbitrary byte values.
    #
    # @param [Integer] min length, inclusive.
    # @param [Integer] max length, inclusive.
    #
    # @return [String]
    #
    def self.genByteString(min,max)
        len = genInt(min,max)
        if len == 0 then return "" 
        else
            return SecureRandom.random_bytes(len)
        end
    end

    #
    # Generate a hex string (two character formatted.)
    #
    # @param [Integer] min length, inclusive. Two string characters for one hex value.
    # @param [Integer] max length, inclusive. Two string characters for one hex value.
    #
    # @return [String]
    #
    def self.genHexString(min,max)
        len = genInt(min,max)
        if len == 0 then return "" 
        else
            return SecureRandom.hex(len)
        end
    end

    #
    # Generate a url safe string.
    # @param [Integer] min length, inclusive.
    # @param [Integer] max length, inclusive.
    #
    # @return [String]
    #
    def self.genUrlSafeString(min,max)
        len = genInt(min,max)
        if len == 0 then return "" 
        else
            return SecureRandom.hex(len)
        end
    end

    #
    # Generates a random symbol.
    #
    # @return [Symbol]
    #
    def self.genSymbol
        suffix = SecureRandom.alphanumeric
        suffix = ('a'..'z').to_a[rand(26)] + suffix
        return suffix.to_sym
    end
        

    #
    # Generates a random int.
    #
    # @param [Integer] min size, inclusive.
    # @param [Integer] max size, inclusive.
    #
    # @return [String]
    #
    def self.genInt(min,max)
        return SecureRandom.random_number(min..max)
    end

    #
    # Generates a random float.
    #
    # @param [Float] min min size, inclusive.
    # @param [Float] max size, exclusive.
    #
    # @return [Float]
    #
    def self.genFloat(min,max)
        return SecureRandom.random_number * (max - min) + min
    end

    #
    # Returns a random true or false.
    #
    # @return [Boolean]
    #
    def self.genBool
        if SecureRandom.random_number < 0.5 then return false
        else return true end
    end

    #
    # Returns the random types that can be generated by a MuckyPup in a set.
    #
    # @return [Set]
    #
    def self.getTypes
        return Set[:alphaNumericString,:symbol,:integer,:float,:bool,:hexString,:urlSafeString,:byteString]
    end
end