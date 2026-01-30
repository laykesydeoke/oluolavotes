;; Analytics Trait - Interface for Governance Analytics

(define-trait analytics-trait
  (
    ;; Track proposal creation
    (record-proposal (uint principal) (response bool uint))

    ;; Track vote cast
    (record-vote (uint principal bool uint) (response bool uint))

    ;; Get voting participation rate
    (get-participation-rate (uint) (response uint uint))

    ;; Get voter statistics
    (get-voter-stats (principal) (response
      {
        proposals-voted: uint,
        proposals-created: uint,
        voting-power-used: uint,
        participation-rate: uint
      }
      uint))

    ;; Get proposal analytics
    (get-proposal-analytics (uint) (response
      {
        total-votes: uint,
        unique-voters: uint,
        average-vote-power: uint,
        time-to-quorum: uint
      }
      uint))

    ;; Get governance health metrics
    (get-governance-health () (response
      {
        active-proposals: uint,
        total-participation: uint,
        average-quorum-time: uint,
        execution-success-rate: uint
      }
      uint))

    ;; Get top voters
    (get-top-voters (uint) (response (list 20 {voter: principal, power: uint}) uint))

    ;; Get voting trends
    (get-voting-trends (uint uint) (response (list 100 {block: uint, votes: uint}) uint))
  )
)
