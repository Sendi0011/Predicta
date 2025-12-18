;; SIP-010 Fungible Token Standard Trait
;; This is the standard trait for fungible tokens on Stacks (like USDC)

(define-trait sip010-ft-trait
  (
    ;; Transfer from the caller to a new principal
    (transfer (uint principal principal (optional (buff 34))) (response bool uint))

    ;; Get the token name
    (get-name () (response (string-ascii 32) uint))

    ;; Get the token symbol
    (get-symbol () (response (string-ascii 32) uint))

    ;; Get the number of decimals used
    (get-decimals () (response uint uint))

    ;; Get the balance of the specified principal
    (get-balance (principal) (response uint uint))

    ;; Get the total supply of the token
    (get-total-supply () (response uint uint))

    ;; Get the token URI
    (get-token-uri () (response (optional (string-utf8 256)) uint))
  )
)