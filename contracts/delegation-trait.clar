;; Delegation Trait - Interface for Vote Delegation

(define-trait delegation-trait
  (
    ;; Delegate voting power to another address
    (delegate (principal) (response bool uint))

    ;; Remove delegation
    (undelegate () (response bool uint))

    ;; Get who an address has delegated to
    (get-delegation (principal) (response (optional principal) uint))

    ;; Get total delegated voting power received by an address
    (get-delegated-power (principal) (response uint uint))

    ;; Get list of delegators for an address
    (get-delegators (principal) (response (list 100 principal) uint))

    ;; Check if delegation is active
    (is-delegating (principal) (response bool uint))

    ;; Get effective voting power (own + delegated)
    (get-effective-power (principal) (response uint uint))

    ;; Delegate for specific proposal only
    (delegate-for-proposal (uint principal) (response bool uint))

    ;; Get delegation history
    (get-delegation-history (principal) (response (list 50 {delegatee: principal, block: uint}) uint))
  )
)
