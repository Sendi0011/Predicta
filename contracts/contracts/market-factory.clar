;; Market Factory Contract
;; Factory for creating prediction markets
;; Manages market deployment and registry

(use-trait ft-trait .sip010-ft-trait.sip010-ft-trait)

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-MARKET-EXISTS (err u115))
(define-constant ERR-INVALID-DURATION (err u116))
(define-constant ERR-INVALID-PARAMS (err u117))
(define-constant ERR-ZERO-ADDRESS (err u118))

;; Data vars
(define-data-var token-contract principal CONTRACT-OWNER)
(define-data-var oracle-contract principal CONTRACT-OWNER)
(define-data-var treasury principal CONTRACT-OWNER)
(define-data-var market-implementation principal CONTRACT-OWNER)
(define-data-var admin principal CONTRACT-OWNER)

;; Default parameters
(define-data-var default-fee-bp uint u200) ;; 2%
(define-data-var default-max-stake-per-user uint u10000000000) ;; 10k USDC
(define-data-var default-max-total-pool uint u1000000000000) ;; 1M USDC
(define-data-var min-market-duration uint u6) ;; ~1 hour in blocks
(define-data-var max-market-duration uint u52560) ;; ~365 days in blocks

;; Market registry
(define-map markets (buff 32) principal)
(define-map is-market principal bool)
(define-map market-counter uint principal) ;; For enumeration
(define-map creator-markets { creator: principal, index: uint } (buff 32))
(define-map creator-market-count principal uint)
(define-map category-markets { category: (string-ascii 50), index: uint } (buff 32))
(define-map category-market-count (string-ascii 50) uint)

;; Roles
(define-map creator-roles principal bool)
(define-map admin-roles principal bool)

;; Statistics
(define-data-var total-markets-created uint u0)
(define-data-var total-volume-usdc uint u0)

;; Helper functions
(define-private (is-admin (user principal))
  (or 
    (is-eq user (var-get admin))
    (default-to false (map-get? admin-roles user))
  )
)

(define-private (has-creator-role (user principal))
  (or
    (is-admin user)
    (default-to false (map-get? creator-roles user))
  )
)

(define-private (get-creator-market-count-internal (creator principal))
  (default-to u0 (map-get? creator-market-count creator))
)

(define-private (get-category-market-count-internal (category (string-ascii 50)))
  (default-to u0 (map-get? category-market-count category))
)

;; Read-only functions
(define-read-only (get-market (market-id (buff 32)))
  (ok (map-get? markets market-id))
)

(define-read-only (verify-market (market-address principal))
  (ok (default-to false (map-get? is-market market-address)))
)

(define-read-only (get-total-markets)
  (ok (var-get total-markets-created))
)

(define-read-only (get-statistics)
  (ok {
    total-markets: (var-get total-markets-created),
    total-volume: (var-get total-volume-usdc),
    default-fee: (var-get default-fee-bp),
    treasury: (var-get treasury)
  })
)

(define-read-only (get-creator-markets (creator principal) (offset uint) (limit uint))
  (let (
    (count (get-creator-market-count-internal creator))
    (end (if (> (+ offset limit) count) count (+ offset limit)))
  )
    (ok (map get-creator-market-at-index 
      (list offset)))
  )
)

(define-private (get-creator-market-at-index (index uint))
  (map-get? creator-markets { creator: tx-sender, index: index })
)

(define-read-only (get-category-markets (category (string-ascii 50)) (offset uint) (limit uint))
  (let (
    (count (get-category-market-count-internal category))
    (end (if (> (+ offset limit) count) count (+ offset limit)))
  )
    (ok count) ;; Simplified - would return array
  )
)

