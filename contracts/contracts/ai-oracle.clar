;; AI Oracle Contract
;; Multi-signature oracle for AI-powered market resolution with challenge mechanism
;; Implements optimistic resolution with challenge period and fallback governance

(use-trait sip010-trait .sip010-ft-trait.sip010-ft-trait)

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant REQUIRED-CONFIRMATIONS u3)
(define-constant CHALLENGE-PERIOD u144) ;; ~24 hours in blocks (assuming 10min blocks)
(define-constant MAX-SIGNATURE-AGE u6) ;; ~1 hour in blocks
(define-constant RESOLUTION-WINDOW u1008) ;; ~7 days in blocks

;; Error codes (from market-types)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-SIGNATURE (err u200))
(define-constant ERR-SIGNATURE-EXPIRED (err u201))
(define-constant ERR-SIGNATURE-TOO-OLD (err u202))
(define-constant ERR-NONCE-USED (err u203))
(define-constant ERR-ALREADY-RESOLVED (err u204))
(define-constant ERR-CHALLENGE-ACTIVE (err u205))
(define-constant ERR-CHALLENGE-EXPIRED (err u206))
(define-constant ERR-INVALID-RESULT (err u207))
(define-constant ERR-ALREADY-VOTED (err u208))
(define-constant ERR-NOT-FINALIZED (err u209))

;; Data vars
(define-data-var admin principal CONTRACT-OWNER)
(define-data-var signer-count uint u0)

;; Data maps
(define-map authorized-signers principal bool)
(define-map admin-roles principal bool)
(define-map resolver-roles principal bool)

;; Market resolution tracking
(define-map resolution-votes 
  { market-id: (buff 32), resolver: principal } 
  uint
)

(define-map vote-counts
  { market-id: (buff 32), side: uint }
  uint
)

(define-map proposed-resolutions
  { market-id: (buff 32) }
  {
    result: uint,
    timestamp: uint,
    proposer: principal,
    challenge-deadline: uint,
    challenged: bool
  }
)

(define-map finalized-resolutions (buff 32) bool)
(define-map used-nonces uint bool)

;; Private functions
(define-private (is-authorized-signer (signer principal))
  (default-to false (map-get? authorized-signers signer))
)

(define-private (has-admin-role (user principal))
  (or 
    (is-eq user (var-get admin))
    (default-to false (map-get? admin-roles user))
  )
)

(define-private (has-resolver-role (user principal))
  (or
    (has-admin-role user)
    (default-to false (map-get? resolver-roles user))
  )
)

(define-private (get-vote-count (market-id (buff 32)) (side uint))
  (default-to u0 (map-get? vote-counts { market-id: market-id, side: side }))
)

(define-private (increment-vote-count (market-id (buff 32)) (side uint))
  (let ((current-count (get-vote-count market-id side)))
    (map-set vote-counts 
      { market-id: market-id, side: side }
      (+ current-count u1)
    )
  )
)

(define-private (propose-resolution-internal 
  (market-id (buff 32)) 
  (result uint) 
  (proposer principal)
)
  (begin
    (map-set proposed-resolutions
      { market-id: market-id }
      {
        result: result,
        timestamp: block-height,
        proposer: proposer,
        challenge-deadline: (+ block-height CHALLENGE-PERIOD),
        challenged: false
      }
    )
    (print {
      event: "resolution-proposed",
      market-id: market-id,
      result: result,
      proposer: proposer,
      challenge-deadline: (+ block-height CHALLENGE-PERIOD)
    })
    (ok true)
  )
)

;; Read-only functions
(define-read-only (is-resolution-finalized (market-id (buff 32)))
  (default-to false (map-get? finalized-resolutions market-id))
)

(define-read-only (get-resolution (market-id (buff 32)))
  (match (map-get? proposed-resolutions { market-id: market-id })
    resolution (if (is-resolution-finalized market-id)
                  (ok (get result resolution))
                  ERR-NOT-FINALIZED)
    ERR-NOT-FINALIZED
  )
)

(define-read-only (get-proposed-resolution (market-id (buff 32)))
  (ok (map-get? proposed-resolutions { market-id: market-id }))
)

(define-read-only (has-user-voted (market-id (buff 32)) (resolver principal))
  (is-some (map-get? resolution-votes { market-id: market-id, resolver: resolver }))
)

(define-read-only (get-signer-count)
  (ok (var-get signer-count))
)

;; Public functions

;; Submit resolution with verification
;; Note: Clarity doesn't have native signature verification like EVM
;; In practice, you'd verify signatures off-chain and have authorized signers submit
(define-public (submit-resolution
  (market-id (buff 32))
  (result uint)
  (nonce uint)
)
  (let (
    (voter tx-sender)
    (current-votes (get-vote-count market-id result))
  )
    ;; Validations
    (asserts! (not (is-resolution-finalized market-id)) ERR-ALREADY-RESOLVED)
    (asserts! (or (is-eq result u1) (is-eq result u2)) ERR-INVALID-RESULT)
    (asserts! (not (default-to false (map-get? used-nonces nonce))) ERR-NONCE-USED)
    (asserts! (not (has-user-voted market-id voter)) ERR-ALREADY-VOTED)
    (asserts! (has-resolver-role voter) ERR-NOT-AUTHORIZED)
    
    ;; Mark nonce as used
    (map-set used-nonces nonce true)
    
    ;; Record vote
    (map-set resolution-votes 
      { market-id: market-id, resolver: voter }
      result
    )
    
    ;; Increment vote count
    (increment-vote-count market-id result)
    
    ;; Emit event
    (print {
      event: "resolution-voted",
      market-id: market-id,
      resolver: voter,
      result: result,
      vote-count: (+ current-votes u1)
    })
    
    ;; Check if consensus reached
    (if (>= (+ current-votes u1) REQUIRED-CONFIRMATIONS)
      (propose-resolution-internal market-id result voter)
      (ok true)
    )
  )
)

;; Finalize resolution after challenge period
(define-public (finalize-resolution (market-id (buff 32)))
  (let (
    (resolution (unwrap! 
      (map-get? proposed-resolutions { market-id: market-id })
      ERR-INVALID-RESULT
    ))
  )
    ;; Validations
    (asserts! (not (is-eq (get result resolution) u0)) ERR-INVALID-RESULT)
    (asserts! (not (is-resolution-finalized market-id)) ERR-ALREADY-RESOLVED)
    (asserts! (>= block-height (get challenge-deadline resolution)) ERR-CHALLENGE-ACTIVE)
    (asserts! (not (get challenged resolution)) ERR-INVALID-RESULT)
    
    ;; Finalize
    (map-set finalized-resolutions market-id true)
    
    ;; Emit event
    (print {
      event: "resolution-finalized",
      market-id: market-id,
      result: (get result resolution),
      confirmations: (get-vote-count market-id (get result resolution))
    })
    
    (ok true)
  )
)

;; Challenge a proposed resolution
(define-public (challenge-resolution 
  (market-id (buff 32)) 
  (reason (string-utf8 500))
)
  (let (
    (resolution (unwrap! 
      (map-get? proposed-resolutions { market-id: market-id })
      ERR-INVALID-RESULT
    ))
  )
    ;; Validations
    (asserts! (not (is-eq (get result resolution) u0)) ERR-INVALID-RESULT)
    (asserts! (< block-height (get challenge-deadline resolution)) ERR-CHALLENGE-EXPIRED)
    (asserts! (not (is-resolution-finalized market-id)) ERR-ALREADY-RESOLVED)
    
    ;; Mark as challenged
    (map-set proposed-resolutions
      { market-id: market-id }
      (merge resolution { challenged: true })
    )
    
    ;; Emit event
    (print {
      event: "resolution-challenged",
      market-id: market-id,
      challenger: tx-sender,
      reason: reason
    })
    
    (ok true)
  )
)

;; Admin override for disputed resolutions
(define-public (admin-resolve 
  (market-id (buff 32)) 
  (result uint)
)
  (begin
    ;; Only admin can call
    (asserts! (has-admin-role tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (or (is-eq result u1) (is-eq result u2)) ERR-INVALID-RESULT)
    
    ;; Set resolution
    (map-set proposed-resolutions
      { market-id: market-id }
      {
        result: result,
        timestamp: block-height,
        proposer: tx-sender,
        challenge-deadline: block-height,
        challenged: false
      }
    )
    
    ;; Finalize immediately
    (map-set finalized-resolutions market-id true)
    
    ;; Emit event
    (print {
      event: "admin-resolution",
      market-id: market-id,
      result: result,
      admin: tx-sender
    })
    
    (ok true)
  )
)

