;; Token Trait - SIP-010 Extended Interface for Governance Tokens

(define-trait token-trait
  (
    ;; SIP-010 Standard Functions
    (transfer (uint principal principal (optional (buff 34))) (response bool uint))
    (get-name () (response (string-ascii 32) uint))
    (get-symbol () (response (string-ascii 32) uint))
    (get-decimals () (response uint uint))
    (get-balance (principal) (response uint uint))
    (get-total-supply () (response uint uint))
    (get-token-uri () (response (optional (string-utf8 256)) uint))

    ;; Governance Extensions
    (mint (uint principal) (response bool uint))
    (burn (uint principal) (response bool uint))

    ;; Snapshot for voting power
    (get-balance-at (principal uint) (response uint uint))
    (get-total-supply-at (uint) (response uint uint))

    ;; Lock tokens for voting
    (lock (uint principal) (response bool uint))
    (unlock (uint principal) (response bool uint))
    (get-locked-balance (principal) (response uint uint))
  )
)
