require 'set'

require_relative "facet_result.rb"
require_relative "operation_result.rb"
require_relative "facet_snapshot.rb"

#
# Indicates an exception occured during a test that was part of the
# test process, not an issue with the Facet code. 
#
class ClauseError < StandardError
    attr_reader :clauseException

    def initialize
        super("Clause error encountered.")
    end
end

#
# Used to define a facet test by chaining function calls and storing the
# result. Runs the clauses and stores the result for processing. Also
# stores a trace of the result at each stage for later retrieval.
#
class FacetClause
    # @return [TestResult] result of the test defined with this class.
    attr_reader :result

    # @!attribute [r] options
    #   @return [FacetOptions] options for the test run.
    # @!attribute [rw] lhsData
    #   @return [Object] the data that we're currently running tests against.
    # @!attribute [rw] lhsOperator
    #   @return [OperationResult] the current lhs operator that will adjust the test result
    # @!attribute [rw] pendingOperator
    #   @return [OperationResult] if we have used two operators in a row (eg and not), stores the 
    #       the operator pending operation (in this case, the and operator).

    #
    # Build a new clause with the result we're populating.
    #
    # @param [TestResult] result to store the outcome of the test in.
    # @param [FacetOptions] options for this test.
    #
    def initialize(result,options)
        @result = result
        @lhsData = nil
        @options = options
        @lhsOperator = nil
        @lastTrace = nil
    end

    #
    # Checks if the value defined in the consumer provided block is the
    # same as the linked {#that} clause. Exact match expected (uses ==). 
    #
    # @return [FacetClause] self to allow chaining.
    #
    # @yield expects the user to define some object to test in the linked block.
    #
    def is
        data = nil
        isStatus = :exception
        begin
            data = yield
            if data != @lhsData then isStatus = :fail 
            else isStatus = :pass end
        rescue => e
            raiseClauseError(:is,e)
        end
        operate(isStatus,:is,:match,data)

        return self
    end

    #
    # Basic matcher, checks that the linked that object matches the object
    # defined in the yielded block. Matching is based on the attributes
    # of the object, such that two different objects whose instance
    # variables all match should evaluate to being identical. 
    #
    # @return [FacetClause] self to allow chaining.
    #
    # @yield expects the user to define some object to test in the linked block.
    #
    def like
        data = nil
        begin
            data = yield
        rescue => e
            raiseClauseError(:like,e)
        end
        matchResult = false
        if FacetSnapshot.simpleType?(data)
            matchResult = (@lhsData == data)
        else
            matchResult = matchObject(@lhsData,data)
        end

        likeStatus = :fail
        if matchResult then likeStatus = :pass end

        operate(likeStatus,:like,:match,data)
        
        return self
    end

    #
    # Checks if the value in @lhsData is of the class
    # returned by the passed block.
    #
    # @return [FacetClause] self to allow chaining.
    #
    # @yield expects the user to define the class we're checking
    #   @lhsData is a kind of.
    #
    def isType
        type = nil
        kindStatus = :exception
        begin
            type = yield
            if !@lhsData.kind_of?(type) then kindStatus = :fail 
            else kindStatus = :pass end
        rescue => e
            raiseClauseError(:kind_of,e)
        end
        operate(kindStatus,:kind_of,:match,type.to_s)

        return self
    end

    #
    # Works like #that, except doesn't update the data defined there.
    # Instead, the element here is cleared after the next operation,
    # returning lhsData to what it was in the setter.
    #
    # @return [FacetClause] self to allow chaining.
    #
    # @yield expects the user to define the object we'll be matching against
    #   in following clauses.
    #
    def pick
        data=nil
        underlyingData = nil
        begin
            underlyingData = @lhsData
            data = yield underlyingData
        rescue => e
            raiseClauseError(:pick,e)
        end
        
        setStatement :pick, data, underlyingData
        return self
    end 

    #
    # Defines code that we're expecting to throw an exception. The
    # data we're operating on is the thrown exception (or nil if no)
    # exception.
    #
    # @return [FacetClause] self to allow chaining.
    #
    # @yield expects the user to define some code that will throw
    #   an exception.
    #
    def err
        data=nil
        begin
            yield
            data = nil
        rescue => e
            data = e
        end
        
        setStatement(:err,data)
        return self
    end

    #
    # Defines the data we'll be matching against in following clauses.
    #
    # @return [FacetClause] self to allow chaining.
    #
    # @yield expects the user to define the object we'll be matching against
    #   in following clauses.
    #
    def that
        data=nil
        begin
            data = yield
        rescue => e
            raiseClauseError(:that,e)
        end
        
        setStatement(:that,data)
        return self
    end

    #
    # Logical not - inverses the result of the next matcher.
    #
    # @param [Proc] block a logical block group, allowing eg not {|t|t.is{ a } .or .is{ b }}
    #
    # @return [FacetClause] self to allow chaining.
    #
    def not(&block)
        if @lhsOperator and @lhsOperator.status == :notImplemented then @pendingOperator = @lhsOperator end
        addCondition(:not,true)
        if block_given? 
            logicBlock(&block)
        end
        return self
    end

    #
    # Logical and - matchers on the left and right side must pass.
    #
    # @param [Proc] block a logical block group, allowing eg `a and {|t|t.is{ b } .or .is{ c }}`
    #
    # @return [FacetClause] self to allow chaining.
    #
    def and(&block)
        addCondition(:and)
        if block_given? 
            logicBlock(&block)
        end
        return self
    end

    #
    # Logical or - a matcher on the left or right side must pass.
    #
    # @param [Proc] block a logical block group, allowing eg `a or {|t|t.is{ b } .or .is{ c }}`
    #
    # @return [FacetClause] self to allow chaining.
    #
    def or(&block)        
        addCondition(:or)
        if block_given? 
            logicBlock(&block)
        end

        return self
    end

    #
    # Logical oxr - either a matcher on the left or right side must pass, but not both.
    #
    # @param [Proc] block a logical block group, allowing eg `a xor {|t|t.is{ b } .or .is{ c }}`
    #
    # @return [FacetClause] self to allow chaining.
    #
    def xor(&block)
        addCondition(:xor)
        if block_given? 
            logicBlock(&block)
        end
        return self
    end

    private

    #
    # Helper function that sets operators and traces when a logical operator is called.
    #
    # @param [Symbol] operation that is being called.
    #
    def addCondition(operation,unary=false)
        @result.status = :notImplemented
        
        if unary
            lhsResult = :pass
            if @lhsOperator then lhsResult = @lhsOperator.status end
            newOp = OperationResult.new(operation,:logic,lhsResult,@lastTrace)
        else
            newOp = OperationResult.new(operation,:logic,@lhsOperator.status,@lastTrace)
            @lhsOperator = @lhsOperator.rhOperator
        end
        if @lhsOperator
        else
        end

        @lhsOperator = newOp
        @lastTrace = @lhsOperator

        if @options.tracingEnabled
            @result.traceOperation(@lhsOperator)
        end
    end

    #
    # A helper function that raises a ClauseException (exception that has arisen from testing the code,
    # not from an error in the Facet source.)
    #
    # @param [Symbol] operation that caused the exception.
    # @param [Exception] exception that was raised.
    #
    # @raise [ClauseError] to terminate execution of the test.
    #
    def raiseClauseError(operation,exception)
        operator = OperationResult.new(operation,:match,nil,nil)
        operator.rhStatus = :exception
        operator.data = exception
        @result.traceOperation(operator)
        @result.status = :exception
        if @options.tracingEnabled
            @result.updateStatus
        end
        
        raise ClauseError.new
    end

    #
    # Runs and performs the appropriate logic operations when a logic block,
    # eg ```not {|t|t.is{ a } .or .is{ b }}```, is encountered.
    #
    # @param [Proc] block the logic block to process.
    #
    def logicBlock(&block)
        farLeftOp = @lhsOperator
        pendingOp = @pendingOperator
        farLeftStatus = @result.status
        @result.status = :pass
        @lhsOperator = nil
        @pendingOp = nil
        
        @lastTrace = OperationResult.new(:blockStart,:logic,@result.status,@lastTrace)
        if @options.tracingEnabled
            @result.traceOperation(@lastTrace)
        end
        block.call(self)
        @lastTrace = OperationResult.new(:blockEnd,:logic,@result.status,@lastTrace)
        if @options.tracingEnabled
            @result.traceOperation(@lastTrace)
        end
        @lhsOperator = farLeftOp
        @pendingOperator = pendingOp
        blockResult = @result.status
        @result.status = farLeftStatus
        @result.status = operate(blockResult,:block,:logic)
        if pendingOp 
            @result.status = operate(@result.status,:block,:logic)
        end
    end

    #
    # Gets the result of an operation with a logical operator.
    #
    # @param [Symbol] lhsResult :pass or :fail.
    # @param [Symbol] operator the logical operator for the operation.
    # @param [Symbol] rhsResult :pass or :fail.
    #
    # @return [Symbol] :pass or :fail based on the operation.
    #
    def getResult(lhsResult,operator,rhsResult) 
        newStatus = :notImplemented
        case operator
        when :or 
            if lhsResult == :pass or rhsResult == :pass 
                newStatus = :pass
            else newStatus = :fail end
        when :and
            if lhsResult == :pass and rhsResult == :pass
                newStatus = :pass
            else newStatus = :fail end
        when :xor
            if lhsResult == :pass and rhsResult == :pass
                newStatus = :fail
            elsif lhsResult == :fail and rhsResult == :fail
                newStatus = :fail
            else newStatus = :pass end
        when :not
            if rhsResult == :pass then newStatus = :fail
            elsif rhsResult == :fail then newStatus = :pass end
        end
        
        return newStatus
    end

    #
    # Used to record data and set state as appropriate for a set operation.
    #
    # @param [Symbol] operator that was used to set data.
    # @param [Object] lhsData the data that was set.
    # @param [Object] underlyingData for pick type operations, allows us to retain an early object
    #   for later reference.
    #
    def setStatement(operator,lhsData,underlyingData=nil)
        if !@lastTrace  
            @lastTrace = OperationResult.new(operator,:set,nil,nil)
        else
            @lastTrace = OperationResult.new(operator,:set,nil,@lastTrace)
        end
        @lastTrace.status = :set
        @lastTrace.rhStatus = :set
        if @result.status == :notImplemented then @result.status = :pass end
        
        if @options.tracingEnabled
            @lastTrace.data = FacetSnapshot.new(lhsData)
            @result.traceOperation(@lastTrace)
        end

        @lhsData = lhsData
        if underlyingData
            @underlyingData = underlyingData
        else @underlyingData = nil end
    end

    #
    # Called when we need to test actual results. Tests the data 
    # provided against the matcher, applies logical operations
    # and stores the result.
    #
    # @param [Symbol] result :pass, :fail of the local test (eg is(true) will be true even if the chain
    #   is .not .is(true)). Important if we're inverting the result based on logical operations.
    # @param [Symbol] operator that was used in this call to operate (eg :that, :is, :like).
    # @param [Symbol] group of the operation - :set, :match or :logic. 
    # @param [Object] data that was produced in the operation.
    #
    def operate(result,operator,group,data=nil)
        opResult = OperationResult.new(operator,group,nil,@lastTrace)
        opResult.rhStatus = result
        if @lhsOperator and @lhsOperator.status == :notImplemented
            @lhsOperator.rhStatus = result
            @lhsOperator.status = getResult(@lhsOperator.lhStatus,@lhsOperator.operation,result)
            result = @lhsOperator.status

            if @pendingOperator
                @pendingOperator.rhStatus = result
                @pendingOperator.status = getResult(@pendingOperator.lhStatus,@pendingOperator.operation,result)
                result = @pendingOperator.status
                @pendingOperator = nil
            end

            if @lhsOperator.operation == :not
                opResult.invert = true
            end
        end
        
        opResult.status = result
        @lastTrace.rhOperator = opResult
        @lastTrace = opResult
        @lhsOperator = @lastTrace

        if result == :fail and !@result.failPoint then @result.failPoint = @lastTrace 
        else @result.failPoint = nil end

        if @options.tracingEnabled
            if operator != :block
                @lastTrace.data = FacetSnapshot.new(data)
            end
            @result.traceOperation(@lastTrace)
        end

        if operator != :pick and @underlyingData != nil
            @lhsData = @underlyingData
        end
        
        @result.status = result
    end

    #
    # Helper function, used to check if two objects match quantitively (eg
    # stored values are equivalent even if the objects aren't the same).
    #
    # @param [Object] lhs to check
    # @param [Object] rhs to check
    # @param [Set] matched objects that have already been matched, acts as an infinite
    #   recursion guard. If we detect recursion, we immediately check the lhs and rhs and if
    #   they're not the same conclude that the objects are not the same.
    #
    # @return [Boolean] 
    #
    def matchObject(lhs,rhs,matched=Set.new)
        if lhs.class != rhs.class then return false end
        if matched.include?(lhs.object_id) or matched.include?(rhs.object_id)
            return lhs == rhs
        end
        matched << lhs.object_id
        matched << rhs.object_id
        if lhs.class == Array
            if lhs.count != rhs.count then return false
            else
                lhs.each_with_index do |ai,idx|
                    if !matchObject(ai,rhs[idx],matched) then return false end
                end
            end
        elsif lhs.class == Hash
            if lhs.count != rhs.count then return false
            else
                lhs.each do |key,value|
                    if !matchObject(value,rhs[key],matched) then return false end
                end
            end
        else
            if FacetSnapshot.simpleType?(lhs)
                return lhs == rhs
            else 
                recursiveVariables = []
                if lhs.instance_variables.sort != rhs.instance_variables.sort then return false end
                lhs.instance_variables.each do |iv|
                    lhsVar = lhs.instance_variable_get(iv)
                    rhsVar = rhs.instance_variable_get(iv)
                    if lhsVar.class != rhsVar.class
                        return false
                    end
                    if FacetSnapshot.simpleType?(lhsVar)
                        if lhsVar != rhsVar then return false end
                    else
                        recursiveVariables << {:lhs=>lhsVar,:rhs=>rhsVar}
                    end
                end
                if recursiveVariables.count > 0
                    recursiveVariables.each do |rv|
                        if !matchObject(rv[:lhs],rv[:rhs],matched) then return false end
                    end
                end
            end
        end
        
        return true
    end
end