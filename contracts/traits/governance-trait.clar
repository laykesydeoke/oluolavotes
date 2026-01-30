;; Governance Trait - Interface for Core Voting Operations
;; This trait defines the standard interface for governance contracts

(define-trait governance-trait
  (
    ;; Get proposal information
    (get-proposal (uint) (response
      {
        proposer: principal,
        title: (string-utf8 100),
        description: (string-utf8 500),
        start-block: uint,
        end-block: uint,
        votes-for: uint,
        votes-against: uint,
        votes-abstain: uint,
        executed: bool
      }
      uint))

    ;; Create a new proposal
    (create-proposal ((string-utf8 100) (string-utf8 500)) (response uint uint))

    ;; Cast a vote on a proposal
    (vote (uint bool) (response bool uint))

    ;; Check if an address has voted on a proposal
    (has-voted (uint principal) (response bool uint))

    ;; Get voting power of an address
    (get-voting-power (principal) (response uint uint))

    ;; Check if proposal is active
    (is-proposal-active (uint) (response bool uint))

    ;; Get total number of proposals
    (get-proposal-count () (response uint uint))
  )
)
