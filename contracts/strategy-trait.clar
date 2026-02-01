;; Strategy Trait - Interface for Voting Strategies

(define-trait strategy-trait
  (
    ;; Calculate voting power based on strategy
    (calculate-voting-power (principal uint) (response uint uint))

    ;; Validate vote based on strategy rules
    (validate-vote (uint principal bool uint) (response bool uint))

    ;; Get strategy name
    (get-strategy-name () (response (string-ascii 50) uint))

    ;; Get strategy parameters
    (get-strategy-params () (response
      {
        weight-type: (string-ascii 20),
        time-weighted: bool,
        quadratic: bool,
        conviction: bool
      }
      uint))

    ;; Calculate quorum based on strategy
    (calculate-quorum (uint) (response uint uint))

    ;; Determine proposal outcome based on strategy
    (determine-outcome (uint) (response
      {
        passed: bool,
        votes-for: uint,
        votes-against: uint,
        votes-abstain: uint,
        threshold-met: bool
      }
      uint))

    ;; Check if strategy allows vote change
    (can-change-vote (uint principal) (response bool uint))

    ;; Get vote weight multiplier
    (get-vote-multiplier (principal uint) (response uint uint))
  )
)
