;; Token Trait - Interface for Governance Token Operations
;; Extends SIP-010 with governance-specific functionality

(define-trait token-trait
  (
    ;; SIP-010 Standard Functions
    (transfer (uint principal principal (optional (buff 34))) (response bool uint))
    (get-name () (response (string-ascii 32) uint))
    (get-symbol () (response (string-ascii 10) uint))
    (get-decimals () (response uint uint))
    (get-balance (principal) (response uint uint))
    (get-total-supply () (response uint uint))
    (get-token-uri () (response (optional (string-utf8 256)) uint))

    ;; Governance Extensions
    ;; Get voting power at specific block height (for snapshots)
    (get-balance-at-block (principal uint) (response uint uint))

    ;; Lock tokens for governance participation
    (lock-tokens (uint principal) (response bool uint))

    ;; Unlock tokens after governance participation
    (unlock-tokens (uint principal) (response bool uint))

    ;; Get locked token balance
    (get-locked-balance (principal) (response uint uint))

    ;; Mint new tokens (admin only)
    (mint (uint principal) (response bool uint))

    ;; Burn tokens
    (burn (uint principal) (response bool uint))
  )
)
