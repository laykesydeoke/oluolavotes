;; Voting Token - SIP-010 Governance Token (Clarity 4)
;; This contract implements a fungible token for governance voting

;; Traits (will be enabled after trait contracts deployed)
;; (impl-trait .token-trait.token-trait)

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant TOKEN-NAME "OluolaVote Token")
(define-constant TOKEN-SYMBOL "OVOTE")
(define-constant TOKEN-DECIMALS u6)
(define-constant TREASURY-ADDRESS CONTRACT-OWNER) ;; Treasury receives STX from token purchases

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-INSUFFICIENT-BALANCE (err u402))
(define-constant ERR-INVALID-AMOUNT (err u403))
(define-constant ERR-TRANSFER-FAILED (err u404))
(define-constant ERR-MINT-FAILED (err u405))
(define-constant ERR-BURN-FAILED (err u406))

;; Data variables
(define-data-var token-uri (optional (string-utf8 256)) none)
(define-data-var total-supply uint u0)

;; Data maps
(define-map balances principal uint)
(define-map allowances { owner: principal, spender: principal } uint)

;; Token holder tracking with Clarity 4 timestamps
(define-map token-holders
    { holder: principal }
    {
        balance: uint,
        first-received: uint,                ;; Clarity 4: Unix timestamp
        last-updated: uint                   ;; Clarity 4: Unix timestamp
    }
)

;; SIP-010 Functions

(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
    (begin
        (asserts! (is-eq tx-sender sender) ERR-NOT-AUTHORIZED)
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)

        (let
            (
                (sender-balance (default-to u0 (map-get? balances sender)))
            )
            (asserts! (>= sender-balance amount) ERR-INSUFFICIENT-BALANCE)

            (map-set balances sender (- sender-balance amount))
            (map-set balances recipient (+ (default-to u0 (map-get? balances recipient)) amount))

            ;; Update token holder tracking
            (map-set token-holders
                { holder: recipient }
                {
                    balance: (+ (default-to u0 (map-get? balances recipient)) amount),
                    first-received: (match (map-get? token-holders { holder: recipient })
                        holder-info (get first-received holder-info)
                        stacks-block-time
                    ),
                    last-updated: stacks-block-time          ;; Clarity 4: Unix timestamp
                }
            )

            (print {
                event: "token-transfer",
                sender: sender,
                recipient: recipient,
                amount: amount,
                memo: memo,
                timestamp: stacks-block-time
            })
            (ok true)
        )
    )
)

(define-read-only (get-name)
    (ok TOKEN-NAME)
)

(define-read-only (get-symbol)
    (ok TOKEN-SYMBOL)
)

(define-read-only (get-decimals)
    (ok TOKEN-DECIMALS)
)

(define-read-only (get-balance (account principal))
    (ok (default-to u0 (map-get? balances account)))
)

(define-read-only (get-total-supply)
    (ok (var-get total-supply))
)

(define-read-only (get-token-uri)
    (ok (var-get token-uri))
)

;; Governance-specific functions

;; Purchase tokens with STX (1 STX = 1000 tokens)
(define-public (buy-tokens (stx-amount uint))
    (let
        (
            (token-amount (* stx-amount u1000))
        )
        (asserts! (> stx-amount u0) ERR-INVALID-AMOUNT)

        ;; Transfer STX from buyer to treasury
        (try! (stx-transfer? stx-amount tx-sender TREASURY-ADDRESS))

        ;; Mint tokens to buyer
        (map-set balances tx-sender (+ (default-to u0 (map-get? balances tx-sender)) token-amount))
        (var-set total-supply (+ (var-get total-supply) token-amount))

        ;; Update holder tracking
        (map-set token-holders
            { holder: tx-sender }
            {
                balance: (+ (default-to u0 (map-get? balances tx-sender)) token-amount),
                first-received: (match (map-get? token-holders { holder: tx-sender })
                    holder-info (get first-received holder-info)
                    stacks-block-time
                ),
                last-updated: stacks-block-time
            }
        )

        (print {
            event: "tokens-purchased",
            buyer: tx-sender,
            stx-amount: stx-amount,
            token-amount: token-amount,
            timestamp: stacks-block-time
        })
        (ok token-amount)
    )
)

;; Mint new tokens (only contract owner)
(define-public (mint (amount uint) (recipient principal))
    (begin
        ;; Check admin access via access-control
        (asserts! (unwrap-panic (contract-call? .access-control is-admin tx-sender)) ERR-NOT-AUTHORIZED)
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)

        (map-set balances recipient (+ (default-to u0 (map-get? balances recipient)) amount))
        (var-set total-supply (+ (var-get total-supply) amount))

        ;; Update token holder tracking
        (map-set token-holders
            { holder: recipient }
            {
                balance: (+ (default-to u0 (map-get? balances recipient)) amount),
                first-received: (match (map-get? token-holders { holder: recipient })
                    holder-info (get first-received holder-info)
                    stacks-block-time
                ),
                last-updated: stacks-block-time              ;; Clarity 4: Unix timestamp
            }
        )

        (print {
            event: "token-minted",
            recipient: recipient,
            amount: amount,
            timestamp: stacks-block-time
        })
        (ok true)
    )
)


;; Get voting power (same as balance for this implementation)
(define-read-only (get-voting-power (account principal))
    (ok (default-to u0 (map-get? balances account)))
)

;; Get token holder information
(define-read-only (get-holder-info (holder principal))
    (ok (map-get? token-holders { holder: holder }))
)

;; Set token URI (only contract owner)
(define-public (set-token-uri (new-uri (string-utf8 256)))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (var-set token-uri (some new-uri))
        (ok true)
    )
)

;; Trait implementation: Lock and unlock tokens
(define-map locked-tokens principal uint)

(define-public (lock (amount uint) (holder principal))
    (let
        (
            (current-locked (default-to u0 (map-get? locked-tokens holder)))
            (balance (default-to u0 (map-get? balances holder)))
        )
        (asserts! (>= balance (+ current-locked amount)) ERR-INSUFFICIENT-BALANCE)
        (map-set locked-tokens holder (+ current-locked amount))
        (ok true)
    )
)

(define-public (unlock (amount uint) (holder principal))
    (let
        (
            (current-locked (default-to u0 (map-get? locked-tokens holder)))
        )
        (asserts! (>= current-locked amount) ERR-INSUFFICIENT-BALANCE)
        (map-set locked-tokens holder (- current-locked amount))
        (ok true)
    )
)

(define-read-only (get-locked-balance (holder principal))
    (ok (default-to u0 (map-get? locked-tokens holder)))
)

;; Snapshot functions for voting power at specific block
(define-map balance-snapshots { holder: principal, block: uint } uint)

(define-read-only (get-balance-at (holder principal) (block uint))
    (ok (default-to u0 (map-get? balance-snapshots { holder: holder, block: block })))
)

(define-read-only (get-total-supply-at (block uint))
    ;; For simplicity, return current total supply
    ;; In production, would need snapshot mechanism
    (ok (var-get total-supply))
)

;; Update burn to match trait signature
(define-public (burn (amount uint) (holder principal))
    (let
        (
            (holder-balance (default-to u0 (map-get? balances holder)))
        )
        (asserts! (is-eq tx-sender holder) ERR-NOT-AUTHORIZED)
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        (asserts! (>= holder-balance amount) ERR-INSUFFICIENT-BALANCE)

        (map-set balances holder (- holder-balance amount))
        (var-set total-supply (- (var-get total-supply) amount))

        (map-set token-holders
            { holder: holder }
            {
                balance: (- holder-balance amount),
                first-received: (match (map-get? token-holders { holder: holder })
                    holder-info (get first-received holder-info)
                    stacks-block-time
                ),
                last-updated: stacks-block-time
            }
        )

        (print {
            event: "token-burned",
            holder: holder,
            amount: amount,
            timestamp: stacks-block-time
        })
        (ok true)
    )
)
