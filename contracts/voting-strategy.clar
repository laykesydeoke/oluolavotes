;; Voting Strategy - Multiple Voting Mechanisms (Clarity 4)
;; This contract implements various voting strategies: simple, weighted, quadratic, ranked-choice

;; Traits (will be enabled after trait contracts deployed)
;; (impl-trait .strategy-trait.strategy-trait)

;; Constants
(define-constant CONTRACT-OWNER tx-sender)

;; Voting strategy types
(define-constant STRATEGY-SIMPLE u1)
(define-constant STRATEGY-WEIGHTED u2)
(define-constant STRATEGY-QUADRATIC u3)
(define-constant STRATEGY-RANKED-CHOICE u4)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u601))
(define-constant ERR-INVALID-STRATEGY (err u602))
(define-constant ERR-PROPOSAL-NOT-FOUND (err u603))
(define-constant ERR-ALREADY-VOTED (err u604))
(define-constant ERR-INVALID-WEIGHT (err u605))
(define-constant ERR-INVALID-RANKING (err u606))

;; Data maps

;; Strategy configuration per proposal
(define-map proposal-strategies
    { proposal-id: uint }
    {
        strategy-type: uint,
        configured-at: uint,                 ;; Clarity 4: Unix timestamp
        min-weight: uint,
        max-weight: uint,
        requires-token: bool
    }
)

;; Weighted votes with Clarity 4 timestamps
(define-map weighted-votes
    { proposal-id: uint, voter: principal }
    {
        weight: uint,
        vote-for: bool,
        timestamp: uint                      ;; Clarity 4: Unix timestamp
    }
)

;; Quadratic votes with Clarity 4 timestamps
(define-map quadratic-votes
    { proposal-id: uint, voter: principal }
    {
        credits-spent: uint,
        vote-for: bool,
        effective-votes: uint,
        timestamp: uint                      ;; Clarity 4: Unix timestamp
    }
)

;; Ranked choice votes with Clarity 4 timestamps
(define-map ranked-votes
    { proposal-id: uint, voter: principal }
    {
        first-choice: uint,
        second-choice: (optional uint),
        third-choice: (optional uint),
        timestamp: uint                      ;; Clarity 4: Unix timestamp
    }
)

;; Proposal vote tallies
(define-map vote-tallies
    { proposal-id: uint }
    {
        simple-for: uint,
        simple-against: uint,
        weighted-for: uint,
        weighted-against: uint,
        quadratic-for: uint,
        quadratic-against: uint,
        total-voters: uint
    }
)

;; Read-only functions

;; Get proposal strategy
(define-read-only (get-proposal-strategy (proposal-id uint))
    (ok (map-get? proposal-strategies { proposal-id: proposal-id }))
)

;; Get weighted vote
(define-read-only (get-weighted-vote (proposal-id uint) (voter principal))
    (ok (map-get? weighted-votes { proposal-id: proposal-id, voter: voter }))
)

;; Get quadratic vote
(define-read-only (get-quadratic-vote (proposal-id uint) (voter principal))
    (ok (map-get? quadratic-votes { proposal-id: proposal-id, voter: voter }))
)

;; Get ranked vote
(define-read-only (get-ranked-vote (proposal-id uint) (voter principal))
    (ok (map-get? ranked-votes { proposal-id: proposal-id, voter: voter }))
)

;; Get vote tally
(define-read-only (get-vote-tally (proposal-id uint))
    (ok (map-get? vote-tallies { proposal-id: proposal-id }))
)

;; Calculate quadratic voting power from credits
(define-read-only (calculate-quadratic-power (credits uint))
    (ok (sqrti credits))
)

;; Public functions

;; Configure voting strategy for a proposal (only owner)
(define-public (configure-strategy (proposal-id uint) (strategy-type uint) (min-weight uint) (max-weight uint) (requires-token bool))
    (begin
        ;; Check admin access via access-control
        (asserts! (unwrap-panic (contract-call? .access-control is-admin tx-sender)) ERR-NOT-AUTHORIZED)
        (asserts! (or
            (is-eq strategy-type STRATEGY-SIMPLE)
            (or
                (is-eq strategy-type STRATEGY-WEIGHTED)
                (or
                    (is-eq strategy-type STRATEGY-QUADRATIC)
                    (is-eq strategy-type STRATEGY-RANKED-CHOICE)
                )
            )
        ) ERR-INVALID-STRATEGY)

        (map-set proposal-strategies
            { proposal-id: proposal-id }
            {
                strategy-type: strategy-type,
                configured-at: stacks-block-time,    ;; Clarity 4: Unix timestamp
                min-weight: min-weight,
                max-weight: max-weight,
                requires-token: requires-token
            }
        )

        ;; Initialize vote tally
        (map-set vote-tallies
            { proposal-id: proposal-id }
            {
                simple-for: u0,
                simple-against: u0,
                weighted-for: u0,
                weighted-against: u0,
                quadratic-for: u0,
                quadratic-against: u0,
                total-voters: u0
            }
        )

        (print {
            event: "strategy-configured",
            proposal-id: proposal-id,
            strategy-type: strategy-type,
            timestamp: stacks-block-time
        })
        (ok true)
    )
)

;; Cast weighted vote
(define-public (vote-weighted (proposal-id uint) (weight uint) (vote-for bool))
    (let
        (
            (strategy (unwrap! (map-get? proposal-strategies { proposal-id: proposal-id }) ERR-PROPOSAL-NOT-FOUND))
            (existing-vote (map-get? weighted-votes { proposal-id: proposal-id, voter: tx-sender }))
        )
        (asserts! (is-eq (get strategy-type strategy) STRATEGY-WEIGHTED) ERR-INVALID-STRATEGY)
        (asserts! (is-none existing-vote) ERR-ALREADY-VOTED)
        (asserts! (and (>= weight (get min-weight strategy)) (<= weight (get max-weight strategy))) ERR-INVALID-WEIGHT)

        ;; Record vote
        (map-set weighted-votes
            { proposal-id: proposal-id, voter: tx-sender }
            {
                weight: weight,
                vote-for: vote-for,
                timestamp: stacks-block-time         ;; Clarity 4: Unix timestamp
            }
        )

        ;; Update tally
        (let
            (
                (tally (unwrap! (map-get? vote-tallies { proposal-id: proposal-id }) ERR-PROPOSAL-NOT-FOUND))
            )
            (map-set vote-tallies
                { proposal-id: proposal-id }
                (merge tally {
                    weighted-for: (if vote-for (+ (get weighted-for tally) weight) (get weighted-for tally)),
                    weighted-against: (if (not vote-for) (+ (get weighted-against tally) weight) (get weighted-against tally)),
                    total-voters: (+ (get total-voters tally) u1)
                })
            )
        )

        (print {
            event: "weighted-vote-cast",
            proposal-id: proposal-id,
            voter: tx-sender,
            weight: weight,
            vote-for: vote-for,
            timestamp: stacks-block-time
        })
        (ok true)
    )
)

;; Cast quadratic vote
(define-public (vote-quadratic (proposal-id uint) (credits uint) (vote-for bool))
    (let
        (
            (strategy (unwrap! (map-get? proposal-strategies { proposal-id: proposal-id }) ERR-PROPOSAL-NOT-FOUND))
            (existing-vote (map-get? quadratic-votes { proposal-id: proposal-id, voter: tx-sender }))
            (effective-votes (sqrti credits))
        )
        (asserts! (is-eq (get strategy-type strategy) STRATEGY-QUADRATIC) ERR-INVALID-STRATEGY)
        (asserts! (is-none existing-vote) ERR-ALREADY-VOTED)
        (asserts! (> credits u0) ERR-INVALID-WEIGHT)

        ;; Record vote
        (map-set quadratic-votes
            { proposal-id: proposal-id, voter: tx-sender }
            {
                credits-spent: credits,
                vote-for: vote-for,
                effective-votes: effective-votes,
                timestamp: stacks-block-time         ;; Clarity 4: Unix timestamp
            }
        )

        ;; Update tally
        (let
            (
                (tally (unwrap! (map-get? vote-tallies { proposal-id: proposal-id }) ERR-PROPOSAL-NOT-FOUND))
            )
            (map-set vote-tallies
                { proposal-id: proposal-id }
                (merge tally {
                    quadratic-for: (if vote-for (+ (get quadratic-for tally) effective-votes) (get quadratic-for tally)),
                    quadratic-against: (if (not vote-for) (+ (get quadratic-against tally) effective-votes) (get quadratic-against tally)),
                    total-voters: (+ (get total-voters tally) u1)
                })
            )
        )

        (print {
            event: "quadratic-vote-cast",
            proposal-id: proposal-id,
            voter: tx-sender,
            credits-spent: credits,
            effective-votes: effective-votes,
            vote-for: vote-for,
            timestamp: stacks-block-time
        })
        (ok true)
    )
)

;; Trait implementation: calculate-voting-power
(define-read-only (calculate-voting-power (voter principal) (proposal-id uint))
    ;; Return base voting power of 1
    (ok u1)
)

;; Trait implementation: validate-vote
(define-read-only (validate-vote (proposal-id uint) (voter principal) (vote-for bool) (weight uint))
    (match (map-get? proposal-strategies { proposal-id: proposal-id })
        strategy (ok true)
        (ok false)
    )
)

;; Trait implementation: get-strategy-name
(define-read-only (get-strategy-name)
    (ok "Multi-Strategy Voting")
)

;; Trait implementation: get-strategy-params
(define-read-only (get-strategy-params)
    (ok {
        weight-type: "dynamic",
        time-weighted: false,
        quadratic: true,
        conviction: false
    })
)

;; Trait implementation: calculate-quorum
(define-read-only (calculate-quorum (proposal-id uint))
    (ok u1000)
)

;; Trait implementation: determine-outcome
(define-read-only (determine-outcome (proposal-id uint))
    (match (map-get? vote-tallies { proposal-id: proposal-id })
        tally (ok {
            passed: (> (+ (get simple-for tally) (get weighted-for tally))
                      (+ (get simple-against tally) (get weighted-against tally))),
            votes-for: (+ (get simple-for tally) (get weighted-for tally)),
            votes-against: (+ (get simple-against tally) (get weighted-against tally)),
            votes-abstain: u0,
            threshold-met: true
        })
        (ok {
            passed: false,
            votes-for: u0,
            votes-against: u0,
            votes-abstain: u0,
            threshold-met: false
        })
    )
)

;; Trait implementation: can-change-vote
(define-read-only (can-change-vote (proposal-id uint) (voter principal))
    (ok false)
)

;; Trait implementation: get-vote-multiplier
(define-read-only (get-vote-multiplier (voter principal) (proposal-id uint))
    (ok u1)
)

;; Cast ranked-choice vote
(define-public (vote-ranked (proposal-id uint) (first uint) (second (optional uint)) (third (optional uint)))
    (let
        (
            (strategy (unwrap! (map-get? proposal-strategies { proposal-id: proposal-id }) ERR-PROPOSAL-NOT-FOUND))
            (existing-vote (map-get? ranked-votes { proposal-id: proposal-id, voter: tx-sender }))
        )
        (asserts! (is-eq (get strategy-type strategy) STRATEGY-RANKED-CHOICE) ERR-INVALID-STRATEGY)
        (asserts! (is-none existing-vote) ERR-ALREADY-VOTED)

        ;; Validate rankings are different
        (asserts! (match second
            s2 (not (is-eq first s2))
            true
        ) ERR-INVALID-RANKING)

        (asserts! (match third
            s3 (and
                (not (is-eq first s3))
                (match second
                    s2 (not (is-eq s2 s3))
                    true
                )
            )
            true
        ) ERR-INVALID-RANKING)

        ;; Record vote
        (map-set ranked-votes
            { proposal-id: proposal-id, voter: tx-sender }
            {
                first-choice: first,
                second-choice: second,
                third-choice: third,
                timestamp: stacks-block-time         ;; Clarity 4: Unix timestamp
            }
        )

        ;; Update total voters
        (let
            (
                (tally (unwrap! (map-get? vote-tallies { proposal-id: proposal-id }) ERR-PROPOSAL-NOT-FOUND))
            )
            (map-set vote-tallies
                { proposal-id: proposal-id }
                (merge tally {
                    total-voters: (+ (get total-voters tally) u1)
                })
            )
        )

        (print {
            event: "ranked-vote-cast",
            proposal-id: proposal-id,
            voter: tx-sender,
            first-choice: first,
            second-choice: second,
            third-choice: third,
            timestamp: stacks-block-time
        })
        (ok true)
    )
)
