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

(define-read-only (get-config)
  (ok {
    token: (var-get token-contract),
    oracle: (var-get oracle-contract),
    treasury: (var-get treasury),
    implementation: (var-get market-implementation),
    default-fee-bp: (var-get default-fee-bp),
    default-max-stake: (var-get default-max-stake-per-user),
    default-max-pool: (var-get default-max-total-pool)
  })
)

;; Public functions

;; Initialize factory
(define-public (initialize
  (token principal)
  (oracle principal)
  (treasury-addr principal)
  (implementation principal)
  (admin-addr principal)
)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    
    (var-set token-contract token)
    (var-set oracle-contract oracle)
    (var-set treasury treasury-addr)
    (var-set market-implementation implementation)
    (var-set admin admin-addr)
    
    (map-set admin-roles admin-addr true)
    (map-set creator-roles admin-addr true)
    
    (ok true)
  )
)

;; Create a new prediction market
(define-public (create-market
  (question (string-utf8 500))
  (category (string-ascii 50))
  (ends-at uint)
  (custom-fee-bp uint)
  (custom-max-stake uint)
  (custom-max-pool uint)
  (market-contract principal)
)
  (let (
    (duration (- ends-at block-height))
    (fee-bp (if (> custom-fee-bp u0) custom-fee-bp (var-get default-fee-bp)))
    (max-stake (if (> custom-max-stake u0) custom-max-stake (var-get default-max-stake-per-user)))
    (max-pool (if (> custom-max-pool u0) custom-max-pool (var-get default-max-total-pool)))
    (market-id (hash-market-params question category ends-at (var-get total-markets-created)))
    (current-count (var-get total-markets-created))
  )
    ;; Validations
    (asserts! (has-creator-role tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (>= duration (var-get min-market-duration)) ERR-INVALID-DURATION)
    (asserts! (<= duration (var-get max-market-duration)) ERR-INVALID-DURATION)
    (asserts! (<= fee-bp u1000) ERR-INVALID-PARAMS)
    (asserts! (is-none (map-get? markets market-id)) ERR-MARKET-EXISTS)
    
    ;; Initialize market contract
    (try! (contract-call? market-contract initialize
      (var-get token-contract)
      (var-get oracle-contract)
      (var-get treasury)
      tx-sender
      market-id
      ends-at
      fee-bp
      max-stake
      max-pool
      question
      (unwrap-panic (to-utf8 category))
    ))
    
    ;; Register market
    (map-set markets market-id market-contract)
    (map-set is-market market-contract true)
    (map-set market-counter current-count market-contract)
    
    ;; Add to creator's markets
    (let ((creator-count (get-creator-market-count-internal tx-sender)))
      (map-set creator-markets 
        { creator: tx-sender, index: creator-count }
        market-id
      )
      (map-set creator-market-count tx-sender (+ creator-count u1))
    )
    
    ;; Add to category
    (let ((cat-count (get-category-market-count-internal category)))
      (map-set category-markets
        { category: category, index: cat-count }
        market-id
      )
      (map-set category-market-count category (+ cat-count u1))
    )
    
    ;; Update counter
    (var-set total-markets-created (+ current-count u1))
    
    (print {
      event: "market-created",
      market-address: market-contract,
      market-id: market-id,
      creator: tx-sender,
      question: question,
      ends-at: ends-at,
      category: category
    })
    
    (ok { market-address: market-contract, market-id: market-id })
  )
)

;; Helper to hash market parameters
(define-private (hash-market-params 
  (question (string-utf8 500))
  (category (string-ascii 50))
  (ends-at uint)
  (counter uint)
)
  (keccak256 (concat
    (concat
      (unwrap-panic (to-consensus-buff? question))
      (unwrap-panic (to-consensus-buff? category))
    )
    (concat
      (unwrap-panic (to-consensus-buff? ends-at))
      (unwrap-panic (to-consensus-buff? counter))
    )
  ))
)

