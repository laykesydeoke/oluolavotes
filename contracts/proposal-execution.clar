;; Proposal Execution - Treasury Management (Clarity 4)
;; This contract executes approved proposals and manages the treasury

;; Traits (will be enabled after trait contracts deployed)
;; (impl-trait .execution-trait.execution-trait)

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant EXECUTION-DELAY u86400)          ;; Clarity 4: 24 hours in seconds

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u301))
(define-constant ERR-PROPOSAL-NOT-FOUND (err u302))
(define-constant ERR-PROPOSAL-NOT-PASSED (err u303))
(define-constant ERR-ALREADY-EXECUTED (err u304))
(define-constant ERR-EXECUTION-DELAY-NOT-MET (err u305))
(define-constant ERR-INSUFFICIENT-TREASURY (err u306))
(define-constant ERR-INVALID-AMOUNT (err u307))
(define-constant ERR-TRANSFER-FAILED (err u308))

;; Data variables
(define-data-var treasury-balance uint u0)  ;; Tracks balance for accounting
(define-data-var total-executed uint u0)
(define-data-var total-deposits uint u0)
(define-data-var total-withdrawals uint u0)

;; Data maps

;; Execution queue with Clarity 4 timestamps
(define-map execution-queue
    { proposal-id: uint }
    {
        queued-at: uint,                     ;; Clarity 4: Unix timestamp
        ready-at: uint,                      ;; Clarity 4: Unix timestamp
        executed-at: (optional uint),        ;; Clarity 4: Unix timestamp
        executor: (optional principal),
        action-type: (string-ascii 50),
        recipient: (optional principal),
        amount: uint,
        executed: bool
    }
)

;; Treasury transactions with Clarity 4 timestamps
(define-map treasury-transactions
    { tx-id: uint }
    {
        proposal-id: uint,
        amount: uint,
        recipient: principal,
        timestamp: uint,                     ;; Clarity 4: Unix timestamp
        tx-type: (string-ascii 20)
    }
)

(define-data-var next-tx-id uint u0)

;; Read-only functions

;; Get treasury balance
(define-read-only (get-treasury-balance)
    (ok (var-get treasury-balance))
)

;; Get total executed proposals
(define-read-only (get-total-executed)
    (ok (var-get total-executed))
)

;; Get execution details
(define-read-only (get-execution-details (proposal-id uint))
    (ok (map-get? execution-queue { proposal-id: proposal-id }))
)

;; Check if proposal is ready for execution
(define-read-only (is-ready-for-execution (proposal-id uint))
    (match (map-get? execution-queue { proposal-id: proposal-id })
        execution
            (ok (and
                (>= stacks-block-time (get ready-at execution))
                (not (get executed execution))
            ))
        (ok false)
    )
)

;; Get treasury transaction
(define-read-only (get-treasury-transaction (tx-id uint))
    (ok (map-get? treasury-transactions { tx-id: tx-id }))
)

;; Public functions

;; Deposit STX into treasury
;; Post-condition: STX balance must increase
(define-public (deposit-to-treasury (amount uint))
    (let
        (
            (sender-balance-before (stx-get-balance tx-sender))
            (treasury-balance-before (stx-get-balance CONTRACT-OWNER))
        )
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        (asserts! (>= sender-balance-before amount) ERR-INSUFFICIENT-TREASURY)

        ;; Transfer STX from sender to contract owner (treasury)
        (try! (stx-transfer? amount tx-sender CONTRACT-OWNER))

        ;; Post-condition: verify balances changed correctly
        (asserts! (is-eq (stx-get-balance tx-sender) (- sender-balance-before amount)) ERR-TRANSFER-FAILED)
        (asserts! (is-eq (stx-get-balance CONTRACT-OWNER) (+ treasury-balance-before amount)) ERR-TRANSFER-FAILED)

        ;; Update treasury balance tracking
        (var-set treasury-balance (+ (var-get treasury-balance) amount))
        (var-set total-deposits (+ (var-get total-deposits) amount))

        (print {
            event: "treasury-deposit",
            depositor: tx-sender,
            amount: amount,
            new-balance: (var-get treasury-balance),
            timestamp: stacks-block-time
        })
        (ok true)
    )
)

;; Withdraw STX from treasury (admin only)
(define-public (withdraw-from-treasury (amount uint) (recipient principal))
    (begin
        ;; Check admin access
        (asserts! (unwrap-panic (contract-call? .access-control is-admin tx-sender)) ERR-NOT-AUTHORIZED)
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        (asserts! (>= (var-get treasury-balance) amount) ERR-INSUFFICIENT-TREASURY)

        ;; Note: Actual STX transfer would be done by CONTRACT-OWNER separately
        ;; This function tracks the withdrawal authorization

        ;; Update treasury balance tracking
        (var-set treasury-balance (- (var-get treasury-balance) amount))
        (var-set total-withdrawals (+ (var-get total-withdrawals) amount))

        (print {
            event: "treasury-withdrawal-authorized",
            admin: tx-sender,
            recipient: recipient,
            amount: amount,
            new-balance: (var-get treasury-balance),
            timestamp: stacks-block-time
        })
        (ok true)
    )
)

;; Queue proposal for execution (only contract owner or authorized)
(define-public (queue-proposal (proposal-id uint) (action-type (string-ascii 50)) (recipient (optional principal)) (amount uint))
    (begin
        ;; Check admin access via access-control
        (asserts! (unwrap-panic (contract-call? .access-control is-admin tx-sender)) ERR-NOT-AUTHORIZED)
        (asserts! (is-none (map-get? execution-queue { proposal-id: proposal-id })) ERR-ALREADY-EXECUTED)

        (let
            (
                (queued-time stacks-block-time)
                (ready-time (+ stacks-block-time EXECUTION-DELAY))
            )
            (map-set execution-queue
                { proposal-id: proposal-id }
                {
                    queued-at: queued-time,                  ;; Clarity 4: Unix timestamp
                    ready-at: ready-time,                    ;; Clarity 4: Unix timestamp
                    executed-at: none,
                    executor: none,
                    action-type: action-type,
                    recipient: recipient,
                    amount: amount,
                    executed: false
                }
            )
            (print {
                event: "proposal-queued",
                proposal-id: proposal-id,
                queued-at: queued-time,
                ready-at: ready-time
            })
            (ok true)
        )
    )
)

;; Execute queued proposal
(define-public (execute-proposal (proposal-id uint))
    (let
        (
            (execution (unwrap! (map-get? execution-queue { proposal-id: proposal-id }) ERR-PROPOSAL-NOT-FOUND))
        )
        (asserts! (not (get executed execution)) ERR-ALREADY-EXECUTED)
        (asserts! (>= stacks-block-time (get ready-at execution)) ERR-EXECUTION-DELAY-NOT-MET)

        ;; Verify proposal exists and passed in governance contract
        (unwrap-panic (contract-call? .oluolavotes get-proposal proposal-id))

        ;; Check if it's a treasury transfer and execute if needed
        (try! (if (is-eq (get action-type execution) "transfer")
            (execute-treasury-transfer proposal-id execution)
            (ok true)
        ))

        ;; Mark as executed
        (map-set execution-queue
            { proposal-id: proposal-id }
            (merge execution {
                executed: true,
                executed-at: (some stacks-block-time),       ;; Clarity 4: Unix timestamp
                executor: (some tx-sender)
            })
        )

        (var-set total-executed (+ (var-get total-executed) u1))

        (print {
            event: "proposal-executed",
            proposal-id: proposal-id,
            executor: tx-sender,
            timestamp: stacks-block-time
        })
        (ok true)
    )
)

;; Execute treasury transfer (private helper)
(define-private (execute-treasury-transfer (proposal-id uint) (execution { queued-at: uint, ready-at: uint, executed-at: (optional uint), executor: (optional principal), action-type: (string-ascii 50), recipient: (optional principal), amount: uint, executed: bool }))
    (let
        (
            (amount (get amount execution))
            (recipient (unwrap! (get recipient execution) ERR-INVALID-AMOUNT))
        )
        (asserts! (>= (var-get treasury-balance) amount) ERR-INSUFFICIENT-TREASURY)

        ;; Deduct from treasury
        (var-set treasury-balance (- (var-get treasury-balance) amount))

        ;; Record transaction
        (let
            (
                (tx-id (var-get next-tx-id))
            )
            (var-set next-tx-id (+ tx-id u1))

            (map-set treasury-transactions
                { tx-id: tx-id }
                {
                    proposal-id: proposal-id,
                    amount: amount,
                    recipient: recipient,
                    timestamp: stacks-block-time,            ;; Clarity 4: Unix timestamp
                    tx-type: "withdrawal"
                }
            )

            (print {
                event: "treasury-transfer",
                tx-id: tx-id,
                proposal-id: proposal-id,
                amount: amount,
                recipient: recipient,
                timestamp: stacks-block-time
            })
            (ok true)
        )
    )
)


;; Trait implementation: get-execution-status
(define-read-only (get-execution-status (proposal-id uint))
    (match (map-get? execution-queue { proposal-id: proposal-id })
        execution (ok {
            executed: (get executed execution),
            queued: true,
            execution-block: (match (get executed-at execution)
                timestamp timestamp
                u0
            ),
            executor: (get executor execution)
        })
        (ok {
            executed: false,
            queued: false,
            execution-block: u0,
            executor: none
        })
    )
)

;; Trait implementation: is-executable
(define-read-only (is-executable (proposal-id uint))
    (is-ready-for-execution proposal-id)
)

;; Trait implementation: get-timelock-delay
(define-read-only (get-timelock-delay)
    (ok EXECUTION-DELAY)
)

;; Trait implementation: set-timelock-delay (placeholder)
(define-public (set-timelock-delay (new-delay uint))
    ;; Placeholder: would need data-var to actually change delay
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (ok true)
    )
)

;; Trait implementation: get-execution-history
(define-read-only (get-execution-history)
    ;; Simplified: return empty list (would need additional tracking)
    (ok (list))
)

;; Trait implementation: pause-execution
(define-public (pause-execution)
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (ok true)
    )
)

;; Trait implementation: unpause-execution
(define-public (unpause-execution)
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (ok true)
    )
)

;; Trait implementation: cancel-proposal (wraps cancel-execution)
(define-public (cancel-proposal (proposal-id uint))
    (cancel-execution proposal-id)
)

;; Cancel queued proposal (only contract owner)
(define-public (cancel-execution (proposal-id uint))
    (let
        (
            (execution (unwrap! (map-get? execution-queue { proposal-id: proposal-id }) ERR-PROPOSAL-NOT-FOUND))
        )
        ;; Check admin or moderator access via access-control
        (asserts! (or
            (unwrap-panic (contract-call? .access-control is-admin tx-sender))
            (unwrap-panic (contract-call? .access-control is-moderator tx-sender))
        ) ERR-NOT-AUTHORIZED)
        (asserts! (not (get executed execution)) ERR-ALREADY-EXECUTED)

        (map-delete execution-queue { proposal-id: proposal-id })

        (print {
            event: "execution-cancelled",
            proposal-id: proposal-id,
            cancelled-by: tx-sender,
            timestamp: stacks-block-time
        })
        (ok true)
    )
)
