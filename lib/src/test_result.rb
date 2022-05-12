#
# Holds the result of a single test within a Facet.
#
class TestResult
    # @return [Symbol] describing the overall status of the test. 
    #   :pass, :fail, :exception or :notImplemented
    attr_accessor :status
    # @return [Hash] trace of what happened with each clause (what was set and returned).
    #  - [Symbol] :operation is the operation that's being traced.
    #  - [Object] :data of the operation
    #  - [Symbol] :status of the operation, :pass, :fail, :exception or :unimplmented
    attr_reader :operationTrace
    # @return [OperationResult|nil] the point at which the test failed, used to limit tracing to 
    #   relevant sections of the test only.
    attr_accessor :failPoint

    #
    # Create a new Test result object for our test.
    #
    def initialize
        @status=:notImplemented
        @operationTrace = []
        @failPoint = nil
    end

    #
    # Record an operation in our test clauses.
    #
    # @param [OperationResult] operation is the operation that's being traced.
    #
    def traceOperation(operation)
        @operationTrace << operation
    end

    #
    # Updates the result of each operation in the test, usually to indicate a test pass or fail.
    #
    def updateStatus
        if @status != :exception
            if @operationTrace[-1].status == :notImplemented and @opertionTrace[1].operation != :that then @status = :notImplemented end
            if @status == :fail

            elsif @status == :pass
                @operationTrace.each do |op|
                    op.status = @status
                end
            end
        end
    end
end