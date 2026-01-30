;; Execution Trait - Interface for Proposal Execution

(define-trait execution-trait
  (
    ;; Execute a passed proposal
    (execute-proposal (uint) (response bool uint))

    ;; Queue proposal for execution (timelock)
    (queue-proposal (uint) (response bool uint))

    ;; Cancel a queued proposal
    (cancel-proposal (uint) (response bool uint))

    ;; Get execution status
    (get-execution-status (uint) (response
      {
        executed: bool,
        queued: bool,
        execution-block: uint,
        executor: (optional principal)
      }
      uint))

    ;; Check if proposal is executable
    (is-executable (uint) (response bool uint))

    ;; Get timelock delay
    (get-timelock-delay () (response uint uint))

    ;; Set timelock delay (admin only)
    (set-timelock-delay (uint) (response bool uint))

    ;; Get proposal execution history
    (get-execution-history () (response (list 100 uint) uint))

    ;; Emergency stop execution
    (pause-execution () (response bool uint))

    ;; Resume execution
    (unpause-execution () (response bool uint))
  )
)
