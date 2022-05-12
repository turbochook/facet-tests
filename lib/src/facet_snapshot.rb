#
# Small class to link a hash key and value together for a {FacetSnapshot}
#
class HashTuple
    # @return [Object] that was serving as the hash key.
    attr_reader :key
    # @return [Object] that was stored at the {#key}
    attr_reader :value

    #
    # Builds a new tuple.
    #
    # @param [Object] key
    # @param [Object] value
    #
    def initialize(key,value)
        @key = key
        @value = value
    end
end

#
# A class that takes a 'snapshot' of another object at a given point in a test.
# Designed to be both a breakdown of an object as well as a deep clone. Can also
# be used to generate a 'difference' between two snapshots.
#
class FacetSnapshot
    # @return [String] identifies the object, usually as either the instance variable that
    #   is storing the object, the array index that the item is at or indicating that the
    #   item is a Hash Tuple.
    attr_reader :name
    # @return [Integer] object_id of the passed object. Helps us deal with recursion.
    attr_reader :id
    # @return [Array[FacetSnapshot]|Object] stores the data of the object. For arrays, hashes
    #   and classes, we store the members in an array of FacetSnapshots with the individual
    #   items similarly broken down.
    attr_reader :data
    # @return [Object] The class of the original data.
    attr_reader :dataType
    # @return [Boolean] whether the stored data is simple - defined as not having members.
    #   See {FacetSnapshot::simpleType?}
    attr_reader :simpleType
    # @return [Boolean] Indicates that the stored data has been referenced elsewhere, and so
    #   we're not showing the full trace here.
    attr_reader :alreadyReferenced

    #
    # Builds a new snapshot for the provided object. Calls recursively for  complex objects.
    #
    # @param [Object] obj to snapshot.
    # @param [String] memberName name, usually of the instance variable storing this obj, otherwise
    #   an array index or "Hash Tuple #{ hash }"
    # @param [Set] matched is used to store any objects that have already been snapshotted so that
    #   we know we don't need to disect them further. Saves on space and acts as a recursion guard.
    #
    def initialize(obj,memberName=nil,matched=nil)  
        @data = {}
        if !matched then matched = Set.new end
        @name = memberName
        @id = obj.object_id
        @dataType = obj.class
        @simpleType = FacetSnapshot.simpleType?(obj)
        if @dataType == FacetDiffList
            @data = {"differences"=>obj}
        elsif !@simpleType and matched.include?(@id)
            @alreadyReferenced = true
        else
            @alreadyReferenced = false
            matched << @id

            if @simpleType
                if obj.kind_of?(Regexp) then @data = obj.inspect
                elsif obj.kind_of?(Symbol) then @data = ":#{obj}"
                elsif obj.respond_to?("to_s") then @data = obj.to_s
                else @data = obj end
            elsif obj.kind_of?(Hash)
                obj.each do |key,val|
                    tupleName = "Hash Tuple #{key.hash}"
                    if @name then tupleName = "#{@name} #{tupleName}" end
                    @data[tupleName] = FacetSnapshot.new(HashTuple.new(key,val),tupleName,matched)
                end    
            elsif obj.kind_of?(Array)
                obj.each_with_index do |val,idx|
                    itemName = "Array Item #{idx}"
                    @data[itemName] = FacetSnapshot.new(val, itemName,matched)
                end
            else
                obj.class.class_variables.each do |cv|
                    @data[cv.to_s] = FacetSnapshot.new(
                        obj.class.class_variable_get(cv),
                        cv.to_s,
                        matched
                    )
                end
                obj.instance_variables.each do |iv|
                    @data[iv.to_s] = FacetSnapshot.new(
                        obj.instance_variable_get(iv),
                        iv.to_s,
                        matched
                    )
                end
            end
        end
    end

    #
    # Helper function that returns a nice summary of an object. 
    # Value for a simple type, or a type and id for a complex type.
    #
    # @param [FacetSnapshot] obj we're summarizing the value for.
    #
    # @return [String]
    #
    def self.simpleValue(obj)
        if obj.simpleType
            if obj.dataType == Regexp then return obj.data.inspect
            elsif obj.dataType == NilClass then return "nil"
            else return obj.data.to_s end
        else
            return "#{obj.dataType} #{obj.id}"
        end
    end

    #
    # Checks two snapshots against each other and returns a snapshot
    # of all the items that are different.
    #
    # @param [FacetSnapshot] lhs 
    # @param [FacetSnapshot] rhs
    #
    # @return [FacetSnapshot] that has all the differences stored in {FacetDiff} and {FacetDiffList}
    #   objects.
    #
    def self.diff(lhs,rhs)
        if lhs.id == rhs.id then return nil end
        if rhs == nil
            if lhs.simpleType and lhs.dataType != Regexp
                return FacetSnapshot.new(FacetDiff.new("#{lhs.data}","nil"))
            else
                return FacetSnapshot.new(FacetDiff.new("#{lhs.dataType} #{lhs.id}","nil"))
            end
        elsif lhs.dataType != rhs.dataType and
            if(
                (lhs.dataType == TrueClass or lhs.dataType == FalseClass) and 
                (rhs.dataType == TrueClass or rhs.dataType == FalseClass)
            )
                return FacetSnapshot.new(FacetDiff.new(lhs.data,rhs.data)) 
            else
                return FacetSnapshot.new(FacetDiff.new(simpleValue(lhs),simpleValue(rhs))) 
            end
        elsif lhs.simpleType and rhs.simpleType
            if lhs.data == rhs.data then return nil
            else return FacetSnapshot.new(FacetDiff.new(lhs.data,rhs.data),lhs.name) end
        elsif lhs.simpleType and !rhs.simpleType
            return FacetSnapshot.new(FacetDiff.new(lhs.data,"#{rhs.dataType} #{rhs.id}"),lhs.name)
        elsif !lhs.simpleType and rhs.simpleType
            return FacetSnapshot.new(FacetDiff.new("#{lhs.dataType} #{lhs.id}",rhs.data),lhs.name)
        elsif lhs.alreadyReferenced or rhs.alreadyReferenced
            lhsData = "#{simpleValue(lhs)}"
            if lhs.alreadyReferenced then lhsData = "Recursive: #{lhsData}" end
            rhsData = "#{simpleValue(rhs)}"
            if rhs.alreadyReferenced then rhsData = "Recursive #{rhsData}" end
            return FacetSnapshot.new(FacetDiff.new(lhsData,rhsData))
        else
            diffs = FacetDiffList.new
            (lhs.data.keys | rhs.data.keys).each do |key|
                if lhs.data[key] == nil and rhs.data[key] == nil
                    next
                elsif lhs.data[key] == nil
                    if rhs.data[key].dataType == HashTuple
                        rhs.data[key].data["@value"] = FacetSnapshot.new(FacetDiff.new("no item at this key",simpleValue(rhs.data[key].data["@value"])),"@value")
                        diffs.pushDiff(rhs.data[key])
                    else
                        diffs.pushDiff(FacetSnapshot.new(FacetDiff.new("no item at this key",simpleValue(rhs.data[key])),key))
                    end
                elsif rhs.data[key] == nil
                    if lhs.data[key].dataType == HashTuple
                        lhs.data[key].data["@value"] = FacetSnapshot.new(FacetDiff.new(simpleValue(lhs.data[key].data["@value"]),"no item at this key"),"@value")
                        diffs.pushDiff(lhs.data[key])
                    else
                        diffs.pushDiff(FacetSnapshot.new(FacetDiff.new(simpleValue(lhs.data[key]),"no item at this key"),key))
                    end
                elsif lhs.data[key].dataType != rhs.data[key].dataType
                    diffs.pushDiff(FacetSnapshot.new(FacetDiff.new(simpleValue(lhs.data[key]),simpleValue(rhs.data[key])),key))
                else
                    res = FacetSnapshot.diff(lhs.data[key],rhs.data[key])
                    if res != nil then diffs.pushDiff(res) end
                end
            end
            if diffs.diffs.count == 0 then return nil
            else 
                if lhs.dataType == HashTuple and rhs.dataType == HashTuple
                    if diffs.diffs.count == 1 and diffs.diffs[0].name == "@value"
                        diffs.insertDiff(lhs.data["@key"])
                    end
                end
                return FacetSnapshot.fromDiffList(diffs,lhs) 
            end
        end
    end

    def self.fromDiffList(diffList,originalSnap)
        diffSnap = FacetSnapshot.new(nil,name)
        diffSnap.instance_variable_set(:@name,originalSnap.name)
        diffSnap.instance_variable_set(:@id,nil)
        diffSnap.instance_variable_set(:@dataType,originalSnap.dataType)
        diffSnap.instance_variable_set(:@simpleType,originalSnap.simpleType)
        diffSnap.instance_variable_set(:@alreadyReferenced,originalSnap.alreadyReferenced)
        diffSnap.instance_variable_set(:@data,{})

        diffList.diffs.each do |dSnap|
            diffSnap.data[dSnap.name] = dSnap
        end

        return diffSnap
    end

    #
    # Canonical function for defining if something is a simple type (no members) or not.
    # Used basically to determine if we need to recurse on snapshotting or can store the 
    # data straight.
    #
    # @param [Object] obj that we're checking.
    #
    # @return [Boolean] true if simple, false if not.
    #
    def self.simpleType?(obj)
        if(
            obj.kind_of? String or
            obj.kind_of? TrueClass or
            obj.kind_of? FalseClass or
            obj.kind_of? NilClass or
            obj.kind_of? Numeric or
            obj.kind_of? Regexp or
            obj.kind_of? Symbol
        )
            return true
        else return false end
    end
end

#
# Class used to store a difference between a lhs and rhs snapshot at
# some level of the snapshot. Has an expected (lhs val) and actual (rhs val)
#
class FacetDiff
    # @return [Object] the value from the setter.
    attr_reader :setResult
    # @return [Object] the value from the matcher.
    attr_reader :matchResult

    #
    # Builds a new FacetDiff from the provided lhs and rhs objects.
    # The expectation is that the lhs is the data from the setter and
    # the rhs is the data from the matcher.
    #
    # @param [Object] lhs the value from the setter.
    # @param [Object] rhs the value from the matcher.
    #
    def initialize(lhs,rhs)
        @setResult = lhs
        @matchResult = rhs
    end
end

#
# Stores a list of diffs, used for objects with multiple members
# and potentially multiple diffs.
#
class FacetDiffList
    # @return [Array[FacetSnapshot]] list of differences between two snapshots at a given level.
    attr_reader :diffs

    #
    # Builds a new FacetDiffList.
    #
    def initialize
        @diffs = []
    end

    #
    # Adds a new difference to the list.
    #
    # @param [FacetSnapshot] d difference to add to the list.
    #
    def pushDiff(d)
        @diffs << d
    end

    #
    # Inserts a new difference at the start of the list.
    #
    # @param [FacetSnapshot] d to insert
    #
    def insertDiff(d)
        @diffs = [d] + @diffs
    end
end