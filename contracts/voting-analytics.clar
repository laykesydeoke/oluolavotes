;; Voting Analytics - Participation & Reputation Tracking (Clarity 4)
;; This contract tracks voter participation, reputation, and generates analytics

;; Traits (will be enabled after trait contracts deployed)
;; (impl-trait .analytics-trait.analytics-trait)

;; Constants
(define-constant CONTRACT-OWNER tx-sender)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u701))
(define-constant ERR-VOTER-NOT-FOUND (err u702))
(define-constant ERR-INVALID-REPUTATION (err u703))

;; Data maps

;; Voter participation stats with Clarity 4 timestamps
(define-map voter-stats
    { voter: principal }
    {
        total-votes-cast: uint,
        proposals-created: uint,
        first-vote: uint,                    ;; Clarity 4: Unix timestamp
        last-vote: uint,                     ;; Clarity 4: Unix timestamp
        reputation-score: uint,
        active-streak: uint
    }
)

;; Proposal participation with Clarity 4 timestamps
(define-map proposal-participation
    { proposal-id: uint }
    {
        total-voters: uint,
        participation-rate: uint,             ;; In basis points (10000 = 100%)
        created-at: uint,                     ;; Clarity 4: Unix timestamp
        voting-ended-at: (optional uint),     ;; Clarity 4: Unix timestamp
        avg-time-to-vote: uint                ;; In seconds
    }
)

;; Voter reputation history with Clarity 4 timestamps
(define-map reputation-history
    { voter: principal, index: uint }
    {
        previous-score: uint,
        new-score: uint,
        reason: (string-ascii 50),
        timestamp: uint                       ;; Clarity 4: Unix timestamp
    }
)

(define-map reputation-count { voter: principal } uint)

;; Global analytics
(define-data-var total-votes-cast uint u0)
(define-data-var total-unique-voters uint u0)
(define-data-var total-proposals uint u0)

;; Leaderboard tracking
(define-map leaderboard-entry
    { rank: uint }
    {
        voter: principal,
        score: uint,
        last-updated: uint                    ;; Clarity 4: Unix timestamp
    }
)

(define-data-var leaderboard-size uint u0)

;; Read-only functions

;; Get voter stats
(define-read-only (get-voter-stats (voter principal))
    (ok (map-get? voter-stats { voter: voter }))
)

;; Get proposal participation
(define-read-only (get-proposal-participation (proposal-id uint))
    (ok (map-get? proposal-participation { proposal-id: proposal-id }))
)

;; Get voter reputation history
(define-read-only (get-reputation-history (voter principal) (index uint))
    (ok (map-get? reputation-history { voter: voter, index: index }))
)

;; Get global stats
(define-read-only (get-global-stats)
    (ok {
        total-votes: (var-get total-votes-cast),
        unique-voters: (var-get total-unique-voters),
        total-proposals: (var-get total-proposals)
    })
)

;; Get leaderboard entry
(define-read-only (get-leaderboard-entry (rank uint))
    (ok (map-get? leaderboard-entry { rank: rank }))
)

;; Get leaderboard size
(define-read-only (get-leaderboard-size)
    (ok (var-get leaderboard-size))
)

;; Calculate participation rate
(define-read-only (calculate-participation-rate (voters uint) (total uint))
    (if (is-eq total u0)
        (ok u0)
        (ok (/ (* voters u10000) total))
    )
)

;; Public functions

;; Record vote (should be called by voting contract)
(define-public (record-vote (voter principal) (proposal-id uint))
    (begin
        (match (map-get? voter-stats { voter: voter })
            existing-stats
                ;; Update existing voter stats
                (map-set voter-stats
                    { voter: voter }
                    {
                        total-votes-cast: (+ (get total-votes-cast existing-stats) u1),
                        proposals-created: (get proposals-created existing-stats),
                        first-vote: (get first-vote existing-stats),
                        last-vote: stacks-block-time,        ;; Clarity 4: Unix timestamp
                        reputation-score: (+ (get reputation-score existing-stats) u1),
                        active-streak: (+ (get active-streak existing-stats) u1)
                    }
                )
            ;; Create new voter stats
            (begin
                (map-set voter-stats
                    { voter: voter }
                    {
                        total-votes-cast: u1,
                        proposals-created: u0,
                        first-vote: stacks-block-time,       ;; Clarity 4: Unix timestamp
                        last-vote: stacks-block-time,        ;; Clarity 4: Unix timestamp
                        reputation-score: u1,
                        active-streak: u1
                    }
                )
                (var-set total-unique-voters (+ (var-get total-unique-voters) u1))
            )
        )

        ;; Increment global vote count
        (var-set total-votes-cast (+ (var-get total-votes-cast) u1))

        ;; Update proposal participation
        (match (map-get? proposal-participation { proposal-id: proposal-id })
            participation
                (map-set proposal-participation
                    { proposal-id: proposal-id }
                    {
                        total-voters: (+ (get total-voters participation) u1),
                        participation-rate: (get participation-rate participation),
                        created-at: (get created-at participation),
                        voting-ended-at: (get voting-ended-at participation),
                        avg-time-to-vote: (get avg-time-to-vote participation)
                    }
                )
            ;; Initialize proposal participation
            (map-set proposal-participation
                { proposal-id: proposal-id }
                {
                    total-voters: u1,
                    participation-rate: u0,
                    created-at: stacks-block-time,           ;; Clarity 4: Unix timestamp
                    voting-ended-at: none,
                    avg-time-to-vote: u0
                }
            )
        )

        (print {
            event: "vote-recorded",
            voter: voter,
            proposal-id: proposal-id,
            timestamp: stacks-block-time
        })
        (ok true)
    )
)

;; Record proposal creation
(define-public (record-proposal-creation (proposer principal) (proposal-id uint))
    (begin
        (match (map-get? voter-stats { voter: proposer })
            existing-stats
                (map-set voter-stats
                    { voter: proposer }
                    {
                        total-votes-cast: (get total-votes-cast existing-stats),
                        proposals-created: (+ (get proposals-created existing-stats) u1),
                        first-vote: (get first-vote existing-stats),
                        last-vote: (get last-vote existing-stats),
                        reputation-score: (+ (get reputation-score existing-stats) u5),
                        active-streak: (get active-streak existing-stats)
                    }
                )
            ;; Create new voter stats for proposer
            (begin
                (map-set voter-stats
                    { voter: proposer }
                    {
                        total-votes-cast: u0,
                        proposals-created: u1,
                        first-vote: stacks-block-time,
                        last-vote: stacks-block-time,
                        reputation-score: u5,
                        active-streak: u0
                    }
                )
                (var-set total-unique-voters (+ (var-get total-unique-voters) u1))
            )
        )

        ;; Increment global proposal count
        (var-set total-proposals (+ (var-get total-proposals) u1))

        ;; Record reputation change
        (let
            (
                (history-index (default-to u0 (map-get? reputation-count { voter: proposer })))
                (current-stats (unwrap-panic (map-get? voter-stats { voter: proposer })))
                (current-score (get reputation-score current-stats))
            )
            (map-set reputation-history
                { voter: proposer, index: history-index }
                {
                    previous-score: (if (> current-score u5) (- current-score u5) u0),
                    new-score: current-score,
                    reason: "proposal-created",
                    timestamp: stacks-block-time             ;; Clarity 4: Unix timestamp
                }
            )
            (map-set reputation-count { voter: proposer } (+ history-index u1))
        )

        (print {
            event: "proposal-created-recorded",
            proposer: proposer,
            proposal-id: proposal-id,
            timestamp: stacks-block-time
        })
        (ok true)
    )
)

;; Update voter reputation (admin function)
(define-public (update-reputation (voter principal) (score-change int) (reason (string-ascii 50)))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)

        (let
            (
                (stats (unwrap! (map-get? voter-stats { voter: voter }) ERR-VOTER-NOT-FOUND))
                (current-score (get reputation-score stats))
                (new-score (if (< score-change 0)
                    (if (> (to-uint (- score-change)) current-score)
                        u0
                        (- current-score (to-uint (- score-change)))
                    )
                    (+ current-score (to-uint score-change))
                ))
                (history-index (default-to u0 (map-get? reputation-count { voter: voter })))
            )
            (map-set voter-stats
                { voter: voter }
                (merge stats { reputation-score: new-score })
            )

            (map-set reputation-history
                { voter: voter, index: history-index }
                {
                    previous-score: current-score,
                    new-score: new-score,
                    reason: reason,
                    timestamp: stacks-block-time             ;; Clarity 4: Unix timestamp
                }
            )

            (map-set reputation-count { voter: voter } (+ history-index u1))

            (print {
                event: "reputation-updated",
                voter: voter,
                previous-score: current-score,
                new-score: new-score,
                reason: reason,
                timestamp: stacks-block-time
            })
            (ok true)
        )
    )
)

;; Trait implementation: record-proposal
(define-public (record-proposal (proposal-id uint) (proposer principal))
    (record-proposal-creation proposer proposal-id)
)

;; Trait implementation: get-participation-rate
(define-read-only (get-participation-rate (proposal-id uint))
    (match (map-get? proposal-participation { proposal-id: proposal-id })
        participation (ok (get participation-rate participation))
        (ok u0)
    )
)


;; Trait implementation: get-proposal-analytics
(define-read-only (get-proposal-analytics (proposal-id uint))
    (match (map-get? proposal-participation { proposal-id: proposal-id })
        participation (ok {
            total-votes: (get total-voters participation),
            unique-voters: (get total-voters participation),
            average-vote-power: u1,
            time-to-quorum: u0
        })
        (ok {
            total-votes: u0,
            unique-voters: u0,
            average-vote-power: u0,
            time-to-quorum: u0
        })
    )
)

;; Trait implementation: get-governance-health
(define-read-only (get-governance-health)
    (ok {
        active-proposals: (var-get total-proposals),
        total-participation: (var-get total-votes-cast),
        average-quorum-time: u0,
        execution-success-rate: u0
    })
)

;; Trait implementation: get-top-voters
(define-read-only (get-top-voters (limit uint))
    ;; Simplified: return empty list (would need leaderboard sorting)
    (ok (list))
)

;; Trait implementation: get-voting-trends
(define-read-only (get-voting-trends (start-block uint) (end-block uint))
    ;; Simplified: return empty list (would need time-series data)
    (ok (list))
)

;; End proposal voting and calculate final participation
(define-public (finalize-proposal-participation (proposal-id uint) (total-eligible-voters uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)

        (let
            (
                (participation (unwrap! (map-get? proposal-participation { proposal-id: proposal-id }) ERR-VOTER-NOT-FOUND))
                (participation-rate (unwrap! (calculate-participation-rate (get total-voters participation) total-eligible-voters) ERR-INVALID-REPUTATION))
            )
            (map-set proposal-participation
                { proposal-id: proposal-id }
                (merge participation {
                    participation-rate: participation-rate,
                    voting-ended-at: (some stacks-block-time)
                })
            )

            (print {
                event: "participation-finalized",
                proposal-id: proposal-id,
                total-voters: (get total-voters participation),
                participation-rate: participation-rate,
                timestamp: stacks-block-time
            })
            (ok true)
        )
    )
)
