;; Decentralized Voting System
;; This contract implements a basic decentralized voting system where users can create proposals and vote on them.

;; Constants

;; The principal who deployed the contract and has administrative privileges
(define-constant CONTRACT-OWNER tx-sender)

;; The duration of the voting period in blocks
(define-constant VOTING-PERIOD u1000)

;; Error codes
(define-constant ERR-NOT-FOUND (err u100))
(define-constant ERR-VOTING-ENDED (err u101))
(define-constant ERR-ALREADY-VOTED (err u102))
(define-constant ERR-VOTING-NOT-ENDED (err u103))
(define-constant ERR-NOT-AUTHORIZED (err u104))
(define-constant ERR-INVALID-TITLE (err u105))
(define-constant ERR-INVALID-DESCRIPTION (err u106))

;; Data maps

;; Stores information about each proposal
(define-map proposals
    { proposal-id: uint }
    {
        title: (string-utf8 50),
        description: (string-utf8 500),
        votes-for: uint,
        votes-against: uint,
        end-block-height: uint
    }
)

;; Tracks votes cast by users
(define-map votes
    { voter: principal, proposal-id: uint }
    { vote: bool }
)

;; Data variables

;; Keeps track of the total number of proposals
(define-data-var proposal-count uint u0)

;; Read-only functions

;; Retrieves information about a specific proposal
;; @param proposal-id The unique identifier of the proposal
;; @returns (response {...} uint) The proposal data or an error if not found
(define-read-only (get-proposal (proposal-id uint))
    (ok (unwrap! (map-get? proposals { proposal-id: proposal-id }) ERR-NOT-FOUND))
)

;; Retrieves a user's vote for a specific proposal
;; @param voter The principal of the voter
;; @param proposal-id The unique identifier of the proposal
;; @returns (response {...} uint) The vote data or an error if not found
(define-read-only (get-vote (voter principal) (proposal-id uint))
    (ok (unwrap! (map-get? votes { voter: voter, proposal-id: proposal-id }) ERR-NOT-FOUND))
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

;; Public functions

;; Creates a new proposal
;; @param title The title of the proposal (max 50 characters)
;; @param description The description of the proposal (max 500 characters)
;; @returns (response uint uint) The new proposal ID or an error
(define-public (create-proposal (title (string-utf8 50)) (description (string-utf8 500)))
    (let
        (
            (title-length (len title))
            (description-length (len description))
        )
        (asserts! (and (> title-length u0) (<= title-length u50)) ERR-INVALID-TITLE)
        (asserts! (and (> description-length u0) (<= description-length u500)) ERR-INVALID-DESCRIPTION)
        (let
            (
                (new-proposal-id (+ (var-get proposal-count) u1))
                (end-block-height (+ block-height VOTING-PERIOD))
            )
            (map-set proposals
                { proposal-id: new-proposal-id }
                {
                    title: title,
                    description: description,
                    votes-for: u0,
                    votes-against: u0,
                    end-block-height: end-block-height
                }
            )
            (var-set proposal-count new-proposal-id)
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
            (proposal (try! (get-proposal proposal-id)))
            (existing-vote (map-get? votes { voter: tx-sender, proposal-id: proposal-id }))
            (checked-vote (if vote-for true false))
        )
        (asserts! (< block-height (get end-block-height proposal)) ERR-VOTING-ENDED)
        (asserts! (is-none existing-vote) ERR-ALREADY-VOTED)
        
        (map-set votes
            { voter: tx-sender, proposal-id: proposal-id }
            { vote: checked-vote }
        )
        
        (map-set proposals
            { proposal-id: proposal-id }
            (merge proposal 
                {
                    votes-for: (if checked-vote (+ (get votes-for proposal) u1) (get votes-for proposal)),
                    votes-against: (if (not checked-vote) (+ (get votes-against proposal) u1) (get votes-against proposal))
                }
            )
        )
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
            (proposal (try! (get-proposal proposal-id)))
        )
        (asserts! (>= block-height (get end-block-height proposal)) ERR-VOTING-NOT-ENDED)
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        
        ;; Implement any post-voting logic here
        
        (ok true)
    )
)
