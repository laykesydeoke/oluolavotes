;; Decentralized Voting System - Clarity 4
;; This contract implements a decentralized voting system with time-based voting periods

;; Traits (will be enabled after trait contracts deployed)
;; (impl-trait .governance-trait.governance-trait)

;; Constants

;; The principal who deployed the contract and has administrative privileges
(define-constant CONTRACT-OWNER tx-sender)

;; The duration of the voting period in seconds (Clarity 4: ~7 days)
(define-constant VOTING-PERIOD u604800)

;; Error codes
(define-constant ERR-NOT-FOUND (err u100))
(define-constant ERR-VOTING-ENDED (err u101))
(define-constant ERR-ALREADY-VOTED (err u102))
(define-constant ERR-VOTING-NOT-ENDED (err u103))
(define-constant ERR-NOT-AUTHORIZED (err u104))
(define-constant ERR-INVALID-TITLE (err u105))
(define-constant ERR-INVALID-DESCRIPTION (err u106))
(define-constant ERR-INVALID-PROPOSAL (err u107))

;; Data maps

;; Stores information about each proposal
(define-map proposals
    { proposal-id: uint }
    {
        title: (string-utf8 100),
        description: (string-utf8 500),
        proposer: principal,
        votes-for: uint,
        votes-against: uint,
        end-time: uint,                     ;; Clarity 4: Unix timestamp
        created-at: uint,                   ;; Clarity 4: Unix timestamp
        executed: bool,
        quorum: uint,
        status: (string-ascii 20)
    }
)

;; Tracks votes cast by users
(define-map votes
    { voter: principal, proposal-id: uint }
    {
        vote: bool,
        timestamp: uint                     ;; Clarity 4: Unix timestamp
    }
)

;; Data variables

;; Keeps track of the total number of proposals
(define-data-var proposal-count uint u0)

;; Minimum quorum percentage (in basis points, 1000 = 10%)
(define-data-var min-quorum-bps uint u1000)

;; Read-only functions

;; Retrieves information about a specific proposal
;; @param proposal-id The unique identifier of the proposal
;; @returns (response {...} uint) The proposal data or an error if not found
(define-read-only (get-proposal (proposal-id uint))
    (match (map-get? proposals { proposal-id: proposal-id })
        proposal (ok {
            proposer: (get proposer proposal),
            title: (get title proposal),
            description: (get description proposal),
            start-block: (get created-at proposal),
            end-block: (get end-time proposal),
            votes-for: (get votes-for proposal),
            votes-against: (get votes-against proposal),
            votes-abstain: u0,
            executed: (get executed proposal)
        })
        ERR-NOT-FOUND
    )
)

;; Retrieves a user's vote for a specific proposal
;; @param voter The principal of the voter
;; @param proposal-id The unique identifier of the proposal
;; @returns (response {...} uint) The vote data or an error if not found
(define-read-only (get-vote (voter principal) (proposal-id uint))
    (ok (unwrap! (map-get? votes { voter: voter, proposal-id: proposal-id }) ERR-NOT-FOUND))
)

;; Get total proposal count
(define-read-only (get-proposal-count)
    (ok (var-get proposal-count))
)

;; Check if voting is active for a proposal
(define-read-only (is-voting-active (proposal-id uint))
    (match (map-get? proposals { proposal-id: proposal-id })
        proposal (ok (< stacks-block-time (get end-time proposal)))
        ERR-NOT-FOUND
    )
)

;; Get voting results for a proposal
(define-read-only (get-voting-results (proposal-id uint))
    (match (map-get? proposals { proposal-id: proposal-id })
        proposal (ok {
            votes-for: (get votes-for proposal),
            votes-against: (get votes-against proposal),
            total-votes: (+ (get votes-for proposal) (get votes-against proposal)),
            status: (get status proposal)
        })
        ERR-NOT-FOUND
    )
)

;; Translates error codes into human-readable messages
;; @param error-code The error code to translate
;; @returns (string-utf8 50) The corresponding error message
(define-read-only (get-error-message (error-code (response bool uint)))
    (match error-code
        ok-value "No error"
        err-value (if (is-eq err-value u100)
            "Proposal not found"
            (if (is-eq err-value u101)
                "Voting period has ended"
                (if (is-eq err-value u102)
                    "User has already voted"
                    (if (is-eq err-value u103)
                        "Voting period has not ended yet"
                        (if (is-eq err-value u104)
                            "Not authorized to perform this action"
                            (if (is-eq err-value u105)
                                "Invalid title length"
                                (if (is-eq err-value u106)
                                    "Invalid description length"
                                    (if (is-eq err-value u107)
                                        "Invalid proposal"
                                        "Unknown error"
                                    )
                                )
                            )
                        )
                    )
                )
            )
        )
    )
)

;; Public functions

;; Creates a new proposal
;; @param title The title of the proposal (max 100 characters)
;; @param description The description of the proposal (max 500 characters)
;; @returns (response uint uint) The new proposal ID or an error
(define-public (create-proposal (title (string-utf8 100)) (description (string-utf8 500)))
    (let
        (
            (title-length (len title))
            (description-length (len description))
        )
        ;; Check if user can create proposals via access control
        (asserts! (unwrap-panic (contract-call? .access-control can-create-proposal tx-sender)) ERR-NOT-AUTHORIZED)

        (asserts! (and (> title-length u0) (<= title-length u100)) ERR-INVALID-TITLE)
        (asserts! (and (> description-length u0) (<= description-length u500)) ERR-INVALID-DESCRIPTION)
        (let
            (
                (new-proposal-id (+ (var-get proposal-count) u1))
                (end-time (+ stacks-block-time VOTING-PERIOD))  ;; Clarity 4: Unix timestamp
            )
            (map-set proposals
                { proposal-id: new-proposal-id }
                {
                    title: title,
                    description: description,
                    proposer: tx-sender,
                    votes-for: u0,
                    votes-against: u0,
                    end-time: end-time,
                    created-at: stacks-block-time,              ;; Clarity 4: Unix timestamp
                    executed: false,
                    quorum: (var-get min-quorum-bps),
                    status: "active"
                }
            )
            (var-set proposal-count new-proposal-id)

            ;; Record proposal creation in analytics contract
            (unwrap-panic (contract-call? .voting-analytics record-proposal-creation tx-sender new-proposal-id))

            (print {
                event: "proposal-created",
                proposal-id: new-proposal-id,
                proposer: tx-sender,
                title: title,
                end-time: end-time
            })
            (ok new-proposal-id)
        )
    )
)

;; Allows a user to vote on a proposal
;; @param proposal-id The unique identifier of the proposal
;; @param vote-for True if voting in favor, false if voting against
;; @returns (response bool uint) True if the vote was successful, or an error
(define-public (vote (proposal-id uint) (vote-for bool))
    (let
        (
            (proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) ERR-NOT-FOUND))
            (existing-vote (map-get? votes { voter: tx-sender, proposal-id: proposal-id }))
        )
        ;; Check if user can vote via access control
        (asserts! (unwrap-panic (contract-call? .access-control can-vote tx-sender)) ERR-NOT-AUTHORIZED)

        (asserts! (< stacks-block-time (get end-time proposal)) ERR-VOTING-ENDED)
        (asserts! (is-none existing-vote) ERR-ALREADY-VOTED)

        (map-set votes
            { voter: tx-sender, proposal-id: proposal-id }
            {
                vote: vote-for,
                timestamp: stacks-block-time                    ;; Clarity 4: Unix timestamp
            }
        )

        (map-set proposals
            { proposal-id: proposal-id }
            (merge proposal
                {
                    votes-for: (if vote-for (+ (get votes-for proposal) u1) (get votes-for proposal)),
                    votes-against: (if (not vote-for) (+ (get votes-against proposal) u1) (get votes-against proposal))
                }
            )
        )

        ;; Record vote in analytics contract
        (unwrap-panic (contract-call? .voting-analytics record-vote tx-sender proposal-id))

        (print {
            event: "vote-cast",
            proposal-id: proposal-id,
            voter: tx-sender,
            vote-for: vote-for,
            timestamp: stacks-block-time
        })
        (ok true)
    )
)

;; Admin functions

;; Ends the voting period for a proposal (can only be called by the contract owner)
;; @param proposal-id The unique identifier of the proposal
;; @returns (response bool uint) True if voting was ended successfully, or an error
(define-public (end-voting (proposal-id uint))
    (let
        (
            (proposal (unwrap! (map-get? proposals { proposal-id: proposal-id }) ERR-NOT-FOUND))
        )
        (asserts! (>= stacks-block-time (get end-time proposal)) ERR-VOTING-NOT-ENDED)
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)

        (let
            (
                (total-votes (+ (get votes-for proposal) (get votes-against proposal)))
                (new-status (if (> (get votes-for proposal) (get votes-against proposal)) "passed" "rejected"))
            )
            (map-set proposals
                { proposal-id: proposal-id }
                (merge proposal { status: new-status })
            )
            (print {
                event: "voting-ended",
                proposal-id: proposal-id,
                status: new-status,
                votes-for: (get votes-for proposal),
                votes-against: (get votes-against proposal)
            })
            (ok true)
        )
    )
)

;; Trait implementation: has-voted
(define-read-only (has-voted (proposal-id uint) (voter principal))
    (match (map-get? votes { voter: voter, proposal-id: proposal-id })
        vote-data (ok true)
        (ok false)
    )
)

;; Trait implementation: get-voting-power
(define-read-only (get-voting-power (voter principal))
    ;; Get voting power from token contract plus delegated power
    (let
        (
            (token-balance (unwrap-panic (contract-call? .voting-token get-balance voter)))
            (delegated-power (unwrap-panic (contract-call? .vote-delegation get-effective-voting-power voter)))
        )
        (ok (+ token-balance delegated-power))
    )
)

;; Trait implementation: is-proposal-active
(define-read-only (is-proposal-active (proposal-id uint))
    (is-voting-active proposal-id)
)

;; Update minimum quorum requirement
(define-public (set-min-quorum (new-quorum-bps uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (asserts! (<= new-quorum-bps u10000) ERR-INVALID-PROPOSAL)
        (var-set min-quorum-bps new-quorum-bps)
        (ok true)
    )
)
