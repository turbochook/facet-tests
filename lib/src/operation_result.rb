#
# Stores a trace of an operation within a test. Used to display
# a list of operations performed, their result, their data and 
# the difference between an actual result and the expected result.
#
# Also used to propogate the results of logical operators along the chain.
# A ```not(true)``` for example will be false, unless paired with 
# ```not(true) xor true```.
#
#
# All operators are only responsible for their rhs element.
# Logic changes propogate up the stack and flip all previous operations. Operators 
# operate on the cumulative result of the chain compared with the rhs.
#
class OperationResult
    # @return [Symbol] of the operation, :pass, :fail, :notImplemented or :exception.
    attr_accessor :status
    # @return [FacetSnapshot] for :set or :match operations, a snapshot of the data 
    #   that was provided by the consumer.
    attr_accessor :data
    # @return [Symbol] whather the rhs operation :pass, :fail, :notImplemented or :exception.
    attr_accessor :rhStatus
    # @return [Symbol] the operation that is being stored here.
    attr_reader :operation
    # @return [Symbol] :set, :match or :logic based on the type of operation.
    attr_reader :operationGroup
    # @return [Symbol] whether the lhs operation :pass, :fail, :exception or :notImplemented.
    attr_reader :lhStatus
    # @return [Boolean] whether this operation has been told to invert the result (eg preceded by a :not)
    attr_accessor :invert
    # @return [OperationResult] the record of the operation to the right. Used for chaining.
    attr_accessor :rhOperator
    # @return [OperationResult] the record of the operation to the left. Used for chaining.
    attr_reader :lhOperator

    #
    # Builds an operation record.
    #
    # @param [Symbol] operation that is being recorded.
    # @param [Symbol] operationGroup :set, :match or :logic group that the operation belongs to.
    # @param [Symbol] lhStatus :pass, :fail, :notImplemented or :exception status of the lhs operator.
    # @param [OperationResult] lhOperator record of the lhs operation.
    #
    def initialize(operation,operationGroup,lhStatus,lhOperator)
        @status = :notImplemented
        @rhStatus = :notImplemented
        @lhStatus = lhStatus
        @operation = operation
        @invert = false
        @lhOperator = lhOperator
        @rhOperator = nil
        @operationGroup = operationGroup
    end


    #
    # We are not really returning the result of the test, simply whether we need to 
    # report on this section of our test based on the overall results.
    # 
    def getResult
        if @rhStatus == :exception
            return :exception
        elsif @status == :set
            then return :set
        elsif @status == :pass
            return :pass
        else
            if @invert and @rhStatus == :fail then return :pass
            elsif @invert and @rhStatus == :pass then return :fail
            else return @status end
        end
    end

    #
    # Used to update whether we need to invert the result of this test
    # (eg if we're preceded by a NOT). Used to identify which logical
    # clauses in a chain caused a failure.
    #
    def switchInversion
        if @invert then @invert = false
        else @invert = true end
    end
end

            