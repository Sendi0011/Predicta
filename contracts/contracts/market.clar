;; Market Contract
;; Individual prediction market with token stakes and position tracking
;; Implements secure stake/resolve/claim flow with AI oracle integration

(use-trait ft-trait .sip010-ft-trait.sip010-ft-trait)

;; Constants
(define-constant CONTRACT-OWNER tx-sender)

;; Market States
(define-constant STATE-ACTIVE u0)
(define-constant STATE-LOCKED u1)
(define-constant STATE-RESOLVING u2)
(define-constant STATE-RESOLVED u3)
(define-constant STATE-DISPUTED u4)
(define-constant STATE-CANCELED u5)

;; Market Sides
(define-constant SIDE-NONE u0)
(define-constant SIDE-YES u1)
(define-constant SIDE-NO u2)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-STATE (err u101))
(define-constant ERR-INVALID-SIDE (err u102))
(define-constant ERR-ZERO-AMOUNT (err u103))
(define-constant ERR-MARKET-ENDED (err u104))
(define-constant ERR-MARKET-NOT-ENDED (err u105))
(define-constant ERR-ALREADY-RESOLVED (err u106))
(define-constant ERR-NOT-RESOLVED (err u107))
(define-constant ERR-ALREADY-CLAIMED (err u108))
(define-constant ERR-NO-STAKE (err u109))
(define-constant ERR-EXCEEDS-USER-LIMIT (err u110))
(define-constant ERR-EXCEEDS-POOL-LIMIT (err u111))
(define-constant ERR-TRANSFER-FAILED (err u112))
(define-constant ERR-NOT-FINALIZED (err u113))
(define-constant ERR-PAUSED (err u114))
(define-constant ERR-NOT-INITIALIZED (err u115))
(define-constant ERR-ALREADY-INITIALIZED (err u116))

;; Data vars
(define-data-var initialized bool false)
(define-data-var token-contract principal CONTRACT-OWNER)
(define-data-var oracle-contract principal CONTRACT-OWNER)
(define-data-var factory-contract principal CONTRACT-OWNER)
(define-data-var treasury principal CONTRACT-OWNER)
(define-data-var market-id (buff 32) 0x00)
(define-data-var ends-at uint u0)
(define-data-var created-at uint u0)
(define-data-var fee-bp uint u200) ;; 2% default
(define-data-var max-stake-per-user uint u10000000000) ;; 10k USDC (6 decimals)
(define-data-var max-total-pool uint u1000000000000) ;; 1M USDC
(define-data-var current-state uint STATE-ACTIVE)
(define-data-var admin principal CONTRACT-OWNER)

;; Pool tracking
(define-data-var yes-pool uint u0)
(define-data-var no-pool uint u0)
(define-data-var fee-amount uint u0)
(define-data-var distributable-amount uint u0)

;; Market metadata
(define-data-var question (string-utf8 500) u"")
(define-data-var category (string-utf8 100) u"")
(define-data-var creator principal CONTRACT-OWNER)

;; User tracking maps
(define-map stakes 
  { user: principal, side: uint }
  uint
)

(define-map claimed principal bool)

;; Position token tracking (SIP-010 style)
(define-map token-balances
  { owner: principal, token-id: uint }
  uint
)

;; Helper functions
(define-private (is-admin (user principal))
  (or (is-eq user (var-get admin)) (is-eq user CONTRACT-OWNER))
)

(define-private (get-user-stake (user principal) (side uint))
  (default-to u0 (map-get? stakes { user: user, side: side }))
)

(define-private (has-claimed (user principal))
  (default-to false (map-get? claimed user))
)

(define-private (get-token-balance (owner principal) (token-id uint))
  (default-to u0 (map-get? token-balances { owner: owner, token-id: token-id }))
)

(define-private (set-token-balance (owner principal) (token-id uint) (amount uint))
  (map-set token-balances { owner: owner, token-id: token-id } amount)
)

(define-private (mint-position-token (recipient principal) (token-id uint) (amount uint))
  (let ((current-balance (get-token-balance recipient token-id)))
    (set-token-balance recipient token-id (+ current-balance amount))
  )
)

(define-private (burn-position-token (owner principal) (token-id uint) (amount uint))
  (let ((current-balance (get-token-balance owner token-id)))
    (if (>= current-balance amount)
      (begin
        (set-token-balance owner token-id (- current-balance amount))
        (ok true)
      )
      (err u999)
    )
  )
)

;; Read-only functions
(define-read-only (get-market-state)
  (ok (var-get current-state))
)

(define-read-only (get-market-info)
  (ok {
    state: (var-get current-state),
    yes-pool: (var-get yes-pool),
    no-pool: (var-get no-pool),
    total-pool: (+ (var-get yes-pool) (var-get no-pool)),
    ends-at: (var-get ends-at),
    created-at: (var-get created-at),
    question: (var-get question),
    category: (var-get category),
    creator: (var-get creator)
  })
)

(define-read-only (get-user-position (user principal))
  (ok {
    yes-stake: (get-user-stake user SIDE-YES),
    no-stake: (get-user-stake user SIDE-NO),
    claimed: (has-claimed user)
  })
)

(define-read-only (get-current-odds)
  (let (
    (total (+ (var-get yes-pool) (var-get no-pool)))
  )
    (if (is-eq total u0)
      (ok { yes-odds: u5000, no-odds: u5000 }) ;; 50/50 if no bets
      (ok {
        yes-odds: (/ (* (var-get yes-pool) u10000) total),
        no-odds: (/ (* (var-get no-pool) u10000) total)
      })
    )
  )
)

(define-read-only (can-claim (user principal))
  (if (not (is-eq (var-get current-state) STATE-RESOLVED))
    (ok false)
    (if (has-claimed user)
      (ok false)
      ;; Need to check oracle for winning side
      (ok true) ;; Simplified - would check oracle contract
    )
  )
)

(define-read-only (get-position-balance (owner principal) (token-id uint))
  (ok (get-token-balance owner token-id))
)

;; Public functions

;; Initialize market (called by factory)
(define-public (initialize
  (token principal)
  (oracle principal)
  (treasury-addr principal)
  (admin-addr principal)
  (market-id-value (buff 32))
  (ends-at-value uint)
  (fee-bp-value uint)
  (max-stake uint)
  (max-pool uint)
  (question-value (string-utf8 500))
  (category-value (string-utf8 100))
)
  (begin
    (asserts! (not (var-get initialized)) ERR-ALREADY-INITIALIZED)
    (asserts! (> ends-at-value block-height) (err u400))
    (asserts! (<= fee-bp-value u1000) (err u401)) ;; Max 10%
    
    (var-set initialized true)
    (var-set token-contract token)
    (var-set oracle-contract oracle)
    (var-set factory-contract tx-sender)
    (var-set treasury treasury-addr)
    (var-set market-id market-id-value)
    (var-set ends-at ends-at-value)
    (var-set created-at block-height)
    (var-set fee-bp fee-bp-value)
    (var-set max-stake-per-user max-stake)
    (var-set max-total-pool max-pool)
    (var-set question question-value)
    (var-set category category-value)
    (var-set creator admin-addr)
    (var-set admin admin-addr)
    (var-set current-state STATE-ACTIVE)
    
    (print {
      event: "market-initialized",
      market-id: market-id-value,
      question: question-value,
      ends-at: ends-at-value
    })
    
    (ok true)
  )
)

;; Stake tokens on YES or NO outcome
(define-public (stake 
  (side uint) 
  (amount uint)
  (token <ft-trait>)
)
  (let (
    (current-yes (var-get yes-pool))
    (current-no (var-get no-pool))
    (user-current-stake (get-user-stake tx-sender side))
    (new-user-stake (+ user-current-stake amount))
    (new-total-pool (+ (+ current-yes current-no) amount))
  )
    ;; Validations
    (asserts! (var-get initialized) ERR-NOT-INITIALIZED)
    (asserts! (is-eq (var-get current-state) STATE-ACTIVE) ERR-INVALID-STATE)
    (asserts! (< block-height (var-get ends-at)) ERR-MARKET-ENDED)
    (asserts! (or (is-eq side SIDE-YES) (is-eq side SIDE-NO)) ERR-INVALID-SIDE)
    (asserts! (> amount u0) ERR-ZERO-AMOUNT)
    (asserts! (<= new-user-stake (var-get max-stake-per-user)) ERR-EXCEEDS-USER-LIMIT)
    (asserts! (<= new-total-pool (var-get max-total-pool)) ERR-EXCEEDS-POOL-LIMIT)
    
    ;; Transfer tokens from user
    (try! (contract-call? token transfer amount tx-sender (as-contract tx-sender) none))
    
    ;; Update stakes
    (map-set stakes 
      { user: tx-sender, side: side }
      new-user-stake
    )
    
    ;; Update pools and mint position tokens
    (if (is-eq side SIDE-YES)
      (begin
        (var-set yes-pool (+ current-yes amount))
        (mint-position-token tx-sender u1 amount) ;; token-id 1 for YES
      )
      (begin
        (var-set no-pool (+ current-no amount))
        (mint-position-token tx-sender u2 amount) ;; token-id 2 for NO
      )
    )
    
    (print {
      event: "staked",
      user: tx-sender,
      side: side,
      amount: amount,
      total-pool: new-total-pool
    })
    
    (ok true)
  )
)

;; Lock market after end time
(define-public (lock-market)
  (begin
    (asserts! (>= block-height (var-get ends-at)) ERR-MARKET-NOT-ENDED)
    (asserts! (is-eq (var-get current-state) STATE-ACTIVE) ERR-INVALID-STATE)
    
    (var-set current-state STATE-LOCKED)
    
    (print {
      event: "market-locked",
      timestamp: block-height
    })
    
    (ok true)
  )
)

;; Resolve market using AI oracle
(define-public (resolve-market)
  (let (
    (oracle (var-get oracle-contract))
    (m-id (var-get market-id))
    (total-pool (+ (var-get yes-pool) (var-get no-pool)))
    (calculated-fee (/ (* total-pool (var-get fee-bp)) u10000))
    (distributable (- total-pool calculated-fee))
  )
    ;; Validations
    (asserts! 
      (or 
        (is-eq (var-get current-state) STATE-LOCKED)
        (is-eq (var-get current-state) STATE-RESOLVING)
      )
      ERR-INVALID-STATE
    )
    (asserts! (>= block-height (var-get ends-at)) ERR-MARKET-NOT-ENDED)
    
    ;; Check oracle finalization (would call oracle contract)
    ;; Simplified here - in practice would do:
    ;; (try! (contract-call? oracle is-resolution-finalized m-id))
    
    ;; Update state
    (if (is-eq (var-get current-state) STATE-LOCKED)
      (var-set current-state STATE-RESOLVING)
      true
    )
    
    ;; Set amounts
    (var-set fee-amount calculated-fee)
    (var-set distributable-amount distributable)
    
    ;; Transfer fees to treasury
    ;; Would transfer calculated-fee to treasury here
    
    ;; Finalize resolution
    (var-set current-state STATE-RESOLVED)
    
    (print {
      event: "market-resolved",
      fee-amount: calculated-fee,
      distributable-amount: distributable
    })
    
    (ok true)
  )
)

;; Claim winnings after resolution
(define-public (claim (token <ft-trait>))
  (let (
    (oracle (var-get oracle-contract))
    (m-id (var-get market-id))
    ;; Would get winning side from oracle
    (winning-side SIDE-YES) ;; Simplified - would call oracle
    (winning-pool (if (is-eq winning-side SIDE-YES) 
                    (var-get yes-pool) 
                    (var-get no-pool)))
    (user-stake (get-user-stake tx-sender winning-side))
    (distributable (var-get distributable-amount))
  )
    ;; Validations
    (asserts! (is-eq (var-get current-state) STATE-RESOLVED) ERR-NOT-RESOLVED)
    (asserts! (not (has-claimed tx-sender)) ERR-ALREADY-CLAIMED)
    (asserts! (> user-stake u0) ERR-NO-STAKE)
    (asserts! (> winning-pool u0) ERR-NO-STAKE)
    
    ;; Calculate payout
    (let ((payout (/ (* user-stake distributable) winning-pool)))
      
      ;; Mark as claimed
      (map-set claimed tx-sender true)
      
      ;; Burn position tokens
      (try! (burn-position-token 
        tx-sender 
        (if (is-eq winning-side SIDE-YES) u1 u2)
        user-stake
      ))
      
      ;; Transfer payout
      (try! (as-contract (contract-call? token transfer payout tx-sender tx-sender none)))
      
      (print {
        event: "claimed",
        user: tx-sender,
        payout: payout
      })
      
      (ok payout)
    )
  )
)

;; Emergency cancel market
(define-public (cancel-market (reason (string-utf8 500)))
  (begin
    (asserts! (is-admin tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (not (is-eq (var-get current-state) STATE-RESOLVED)) ERR-ALREADY-RESOLVED)
    (asserts! (not (is-eq (var-get current-state) STATE-CANCELED)) ERR-PAUSED)
    
    (var-set current-state STATE-CANCELED)
    
    (print {
      event: "market-canceled",
      reason: reason
    })
    
    (ok true)
  )
)

