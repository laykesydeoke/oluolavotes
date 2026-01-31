;; Vote Delegation - Delegated Voting Power (Clarity 4)
;; This contract allows users to delegate their voting power to others

;; Traits (will be enabled after trait contracts deployed)
;; (impl-trait .delegation-trait.delegation-trait)

;; Constants
(define-constant CONTRACT-OWNER tx-sender)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u201))
(define-constant ERR-INVALID-DELEGATE (err u202))
(define-constant ERR-ALREADY-DELEGATED (err u203))
(define-constant ERR-NOT-DELEGATED (err u204))
(define-constant ERR-CIRCULAR-DELEGATION (err u205))
(define-constant ERR-SELF-DELEGATION (err u206))
(define-constant ERR-INSUFFICIENT-BALANCE (err u207))

;; Data variables
(define-data-var total-active-delegations uint u0)

;; Data maps

;; Delegation records with Clarity 4 timestamps
(define-map delegations
    { delegator: principal }
    {
        delegate: principal,
        delegated-at: uint,                  ;; Clarity 4: Unix timestamp
        expires-at: (optional uint),         ;; Clarity 4: Unix timestamp
        active: bool
    }
)

;; Track delegated power received
(define-map delegated-power
    { delegate: principal }
    {
        delegator-count: uint,
        total-power: uint,
        last-updated: uint                   ;; Clarity 4: Unix timestamp
    }
)

;; Delegation history with Clarity 4 timestamps
(define-map delegation-history
    { delegator: principal, index: uint }
    {
        delegate: principal,
        delegated-at: uint,                  ;; Clarity 4: Unix timestamp
        revoked-at: (optional uint)          ;; Clarity 4: Unix timestamp
    }
)

(define-map delegation-count { delegator: principal } uint)

;; Track locked tokens for delegation
(define-map delegation-locks
    { delegator: principal }
    {
        locked-amount: uint,
        locked-at: uint                      ;; Clarity 4: Unix timestamp
    }
)

;; Read-only functions

;; Get current delegation
(define-read-only (get-delegation (delegator principal))
    (ok (map-get? delegations { delegator: delegator }))
)

;; Get delegated power received by a delegate
(define-read-only (get-delegated-power (delegatee principal))
    (ok (map-get? delegated-power { delegate: delegatee }))
)

;; Check if delegation is active
(define-read-only (is-delegated (delegator principal))
    (match (map-get? delegations { delegator: delegator })
        delegation (ok (get active delegation))
        (ok false)
    )
)

;; Get effective voting power (own + delegated)
(define-read-only (get-effective-voting-power (voter principal))
    (let
        (
            (own-power u1)  ;; Base voting power
            (delegated (default-to { delegator-count: u0, total-power: u0, last-updated: u0 } (map-get? delegated-power { delegate: voter })))
        )
        (ok (+ own-power (get total-power delegated)))
    )
)

;; Get delegation history
(define-read-only (get-delegation-history (delegator principal) (index uint))
    (ok (map-get? delegation-history { delegator: delegator, index: index }))
)

;; Get total delegation count for delegator
(define-read-only (get-delegation-count (delegator principal))
    (ok (default-to u0 (map-get? delegation-count { delegator: delegator })))
)

;; Get delegation lock info
(define-read-only (get-delegation-lock (delegator principal))
    (ok (map-get? delegation-locks { delegator: delegator }))
)

;; Check if tokens are locked for delegation
(define-read-only (has-locked-delegation (delegator principal))
    (ok (is-some (map-get? delegation-locks { delegator: delegator })))
)

;; Get total active delegations
(define-read-only (get-total-delegations)
    (ok (var-get total-active-delegations))
)

;; Public functions

;; Delegate voting power to another user
(define-public (delegate-vote (delegatee principal) (duration-seconds (optional uint)))
    (begin
        (asserts! (not (is-eq tx-sender delegatee)) ERR-SELF-DELEGATION)

        ;; Check for circular delegation
        (asserts! (not (unwrap! (is-delegated delegatee) ERR-INVALID-DELEGATE)) ERR-CIRCULAR-DELEGATION)

        ;; Verify delegatee has voting tokens
        (asserts! (> (unwrap-panic (contract-call? .voting-token get-balance delegatee)) u0) ERR-INVALID-DELEGATE)

        ;; Check if already delegated
        (try! (match (map-get? delegations { delegator: tx-sender })
            existing-delegation
                (if (get active existing-delegation)
                    ERR-ALREADY-DELEGATED
                    (ok true)
                )
            (ok true)
        ))

        ;; Get delegator's token balance and lock it
        (let
            (
                (delegator-balance (unwrap! (contract-call? .voting-token get-balance tx-sender) ERR-INSUFFICIENT-BALANCE))
                (expires-at (match duration-seconds
                    duration (some (+ stacks-block-time duration))
                    none
                ))
                (history-index (default-to u0 (map-get? delegation-count { delegator: tx-sender })))
            )
            (asserts! (> delegator-balance u0) ERR-INSUFFICIENT-BALANCE)

            ;; Lock the delegator's tokens
            (unwrap! (contract-call? .voting-token lock delegator-balance tx-sender) ERR-INSUFFICIENT-BALANCE)

            ;; Track the locked tokens
            (map-set delegation-locks
                { delegator: tx-sender }
                {
                    locked-amount: delegator-balance,
                    locked-at: stacks-block-time
                }
            )
            ;; Create delegation
            (map-set delegations
                { delegator: tx-sender }
                {
                    delegate: delegatee,
                    delegated-at: stacks-block-time,         ;; Clarity 4: Unix timestamp
                    expires-at: expires-at,
                    active: true
                }
            )

            ;; Update delegated power for delegate
            (match (map-get? delegated-power { delegate: delegatee })
                existing-power
                    (map-set delegated-power
                        { delegate: delegatee }
                        {
                            delegator-count: (+ (get delegator-count existing-power) u1),
                            total-power: (+ (get total-power existing-power) u1),
                            last-updated: stacks-block-time  ;; Clarity 4: Unix timestamp
                        }
                    )
                ;; First delegation to this delegate
                (map-set delegated-power
                    { delegate: delegatee }
                    {
                        delegator-count: u1,
                        total-power: u1,
                        last-updated: stacks-block-time      ;; Clarity 4: Unix timestamp
                    }
                )
            )

            ;; Record in history
            (map-set delegation-history
                { delegator: tx-sender, index: history-index }
                {
                    delegate: delegatee,
                    delegated-at: stacks-block-time,
                    revoked-at: none
                }
            )

            (map-set delegation-count { delegator: tx-sender } (+ history-index u1))
            (var-set total-active-delegations (+ (var-get total-active-delegations) u1))

            (print {
                event: "vote-delegated",
                delegator: tx-sender,
                delegate: delegatee,
                amount-locked: delegator-balance,
                timestamp: stacks-block-time,
                expires-at: expires-at
            })
            (ok true)
        )
    )
)

;; Revoke delegation
(define-public (revoke-delegation)
    (let
        (
            (delegation (unwrap! (map-get? delegations { delegator: tx-sender }) ERR-NOT-DELEGATED))
            (lock-info (unwrap! (map-get? delegation-locks { delegator: tx-sender }) ERR-NOT-DELEGATED))
        )
        (asserts! (get active delegation) ERR-NOT-DELEGATED)

        (let
            (
                (delegatee (get delegate delegation))
                (history-index (- (default-to u1 (map-get? delegation-count { delegator: tx-sender })) u1))
                (locked-amount (get locked-amount lock-info))
            )
            ;; Unlock the delegator's tokens
            (unwrap! (contract-call? .voting-token unlock locked-amount tx-sender) ERR-NOT-AUTHORIZED)

            ;; Remove lock record
            (map-delete delegation-locks { delegator: tx-sender })

            ;; Mark delegation as inactive
            (map-set delegations
                { delegator: tx-sender }
                (merge delegation { active: false })
            )

            ;; Update delegated power for delegate
            (match (map-get? delegated-power { delegate: delegatee })
                existing-power
                    (map-set delegated-power
                        { delegate: delegatee }
                        {
                            delegator-count: (- (get delegator-count existing-power) u1),
                            total-power: (- (get total-power existing-power) u1),
                            last-updated: stacks-block-time  ;; Clarity 4: Unix timestamp
                        }
                    )
                true  ;; Should not happen, but handle gracefully
            )

            ;; Update history
            (match (map-get? delegation-history { delegator: tx-sender, index: history-index })
                history-entry
                    (map-set delegation-history
                        { delegator: tx-sender, index: history-index }
                        (merge history-entry { revoked-at: (some stacks-block-time) })
                    )
                true
            )

            (var-set total-active-delegations (- (var-get total-active-delegations) u1))

            (print {
                event: "delegation-revoked",
                delegator: tx-sender,
                delegate: delegatee,
                amount-unlocked: locked-amount,
                timestamp: stacks-block-time
            })
            (ok true)
        )
    )
)


;; Check and expire delegations (can be called by anyone)
(define-public (expire-delegation (delegator principal))
    (let
        (
            (delegation (unwrap! (map-get? delegations { delegator: delegator }) ERR-NOT-DELEGATED))
        )
        (asserts! (get active delegation) ERR-NOT-DELEGATED)

        (match (get expires-at delegation)
            expiry-time
                (begin
                    (asserts! (>= stacks-block-time expiry-time) ERR-NOT-AUTHORIZED)

                    (let
                        (
                            (delegatee (get delegate delegation))
                        )
                        ;; Mark as inactive
                        (map-set delegations
                            { delegator: delegator }
                            (merge delegation { active: false })
                        )

                        ;; Update delegated power
                        (match (map-get? delegated-power { delegate: delegatee })
                            existing-power
                                (map-set delegated-power
                                    { delegate: delegatee }
                                    {
                                        delegator-count: (- (get delegator-count existing-power) u1),
                                        total-power: (- (get total-power existing-power) u1),
                                        last-updated: stacks-block-time
                                    }
                                )
                            true
                        )

                        (print {
                            event: "delegation-expired",
                            delegator: delegator,
                            delegate: delegatee,
                            timestamp: stacks-block-time
                        })
                        (ok true)
                    )
                )
            ERR-NOT-AUTHORIZED  ;; No expiry set
        )
    )
)

;; Trait implementation: delegate
(define-public (delegate (delegatee principal))
    (begin
        (asserts! (not (is-eq tx-sender delegatee)) ERR-SELF-DELEGATION)
        (asserts! (not (unwrap! (is-delegated delegatee) ERR-INVALID-DELEGATE)) ERR-CIRCULAR-DELEGATION)
        (try! (match (map-get? delegations { delegator: tx-sender })
            existing-delegation
                (if (get active existing-delegation)
                    ERR-ALREADY-DELEGATED
                    (ok true)
                )
            (ok true)
        ))
        (map-set delegations
            { delegator: tx-sender }
            {
                delegate: delegatee,
                delegated-at: stacks-block-time,
                expires-at: none,
                active: true
            }
        )
        (match (map-get? delegated-power { delegate: delegatee })
            existing-power
                (map-set delegated-power
                    { delegate: delegatee }
                    {
                        delegator-count: (+ (get delegator-count existing-power) u1),
                        total-power: (+ (get total-power existing-power) u1),
                        last-updated: stacks-block-time
                    }
                )
            (map-set delegated-power
                { delegate: delegatee }
                {
                    delegator-count: u1,
                    total-power: u1,
                    last-updated: stacks-block-time
                }
            )
        )
        (ok true)
    )
)

;; Trait implementation: undelegate
(define-public (undelegate)
    (let
        (
            (delegation (unwrap! (map-get? delegations { delegator: tx-sender }) ERR-NOT-DELEGATED))
        )
        (asserts! (get active delegation) ERR-NOT-DELEGATED)
        (map-set delegations
            { delegator: tx-sender }
            (merge delegation { active: false })
        )
        (ok true)
    )
)

;; Trait implementation: get-delegators
(define-read-only (get-delegators (delegatee principal))
    (ok (list))
)

;; Trait implementation: is-delegating
(define-read-only (is-delegating (delegator principal))
    (match (map-get? delegations { delegator: delegator })
        delegation (ok (get active delegation))
        (ok false)
    )
)

;; Trait implementation: delegate-for-proposal
(define-public (delegate-for-proposal (proposal-id uint) (delegatee principal))
    (delegate delegatee)
)
