;; FitChain Protocol
;; A decentralized fitness tracking and reward system

;; Constants
(define-constant MAX_TOKEN_SUPPLY u5000000)
(define-constant BASE_WORKOUT_REWARD u15)
(define-constant CONSISTENCY_MULTIPLIER u3)
(define-constant MAX_CONSISTENCY_LEVEL u10)
(define-constant ERR_INVALID_WORKOUT u1)
(define-constant ERR_NO_TOKENS u2)
(define-constant ERR_SUPPLY_EXHAUSTED u3)
(define-constant BLOCKS_PER_WORKOUT_CYCLE u288)
(define-constant DEDICATION_MULTIPLIER u4)
(define-constant MIN_DEDICATION_BLOCKS u576)
(define-constant EARLY_WITHDRAWAL_FEE u15)

;; Data Variables
(define-data-var total-tokens-distributed uint u0)
(define-data-var total-workouts-logged uint u0)
(define-data-var protocol-owner principal tx-sender)

;; Data Maps
(define-map athlete-workouts principal uint)
(define-map athlete-tokens principal uint)
(define-map workout-start-block principal uint)
(define-map consistency-level principal uint)
(define-map last-workout-block principal uint)
(define-map locked-tokens principal uint)
(define-map lock-start-block principal uint)

;; Public Functions

(define-public (start-workout (intensity uint))
  (let
    (
      (athlete tx-sender)
    )
    (asserts! (> intensity u0) (err ERR_INVALID_WORKOUT))
    (map-set workout-start-block athlete burn-block-height)
    (ok true)
  )
)

(define-public (finish-workout (intensity uint))
  (let
    (
      (athlete tx-sender)
      (start-block (default-to u0 (map-get? workout-start-block athlete)))
      (blocks-trained (- burn-block-height start-block))
      (previous-workout-block (default-to u0 (map-get? last-workout-block athlete)))
      (current-consistency (default-to u0 (map-get? consistency-level athlete)))
      (capped-consistency (if (<= current-consistency MAX_CONSISTENCY_LEVEL) current-consistency MAX_CONSISTENCY_LEVEL))
      (token-reward (+ BASE_WORKOUT_REWARD (* capped-consistency CONSISTENCY_MULTIPLIER)))
    )
    (asserts! (and (> start-block u0) (>= blocks-trained intensity)) (err ERR_INVALID_WORKOUT))
    (map-set athlete-workouts athlete (+ (default-to u0 (map-get? athlete-workouts athlete)) u1))
    (map-set athlete-tokens athlete (+ (default-to u0 (map-get? athlete-tokens athlete)) token-reward))
    (if (< (- burn-block-height previous-workout-block) BLOCKS_PER_WORKOUT_CYCLE)
      (map-set consistency-level athlete (+ current-consistency u1))
      (map-set consistency-level athlete u1)
    )
    (map-set last-workout-block athlete burn-block-height)
    (var-set total-workouts-logged (+ (var-get total-workouts-logged) u1))
    (var-set total-tokens-distributed (+ (var-get total-tokens-distributed) token-reward))
    (asserts! (<= (var-get total-tokens-distributed) MAX_TOKEN_SUPPLY) (err ERR_SUPPLY_EXHAUSTED))
    (ok token-reward)
  )
)

(define-public (withdraw-tokens)
  (let
    (
      (athlete tx-sender)
      (token-balance (default-to u0 (map-get? athlete-tokens athlete)))
    )
    (asserts! (> token-balance u0) (err ERR_NO_TOKENS))
    (map-set athlete-tokens athlete u0)
    (ok token-balance)
  )
)

;; Dedication Features

(define-public (lock-tokens (amount uint))
  (let
    (
      (athlete tx-sender)
    )
    (asserts! (> amount u0) (err ERR_INVALID_WORKOUT))
    (asserts! (>= (var-get total-tokens-distributed) amount) (err ERR_SUPPLY_EXHAUSTED))
    (map-set locked-tokens athlete amount)
    (map-set lock-start-block athlete burn-block-height)
    (var-set total-tokens-distributed (- (var-get total-tokens-distributed) amount))
    (ok amount)
  )
)

(define-public (unlock-tokens)
  (let
    (
      (athlete tx-sender)
      (locked-amount (default-to u0 (map-get? locked-tokens athlete)))
      (lock-block (default-to u0 (map-get? lock-start-block athlete)))
      (blocks-locked (- burn-block-height lock-block))
      (fee (if (< blocks-locked MIN_DEDICATION_BLOCKS) (/ (* locked-amount EARLY_WITHDRAWAL_FEE) u100) u0))
      (final-amount (- locked-amount fee))
    )
    (asserts! (> locked-amount u0) (err ERR_NO_TOKENS))
    (map-set locked-tokens athlete u0)
    (map-set lock-start-block athlete u0)
    (var-set total-tokens-distributed (+ (var-get total-tokens-distributed) final-amount))
    (ok final-amount)
  )
)

;; Read-Only Functions

(define-read-only (get-workout-count (user principal))
  (default-to u0 (map-get? athlete-workouts user))
)

(define-read-only (get-token-balance (user principal))
  (default-to u0 (map-get? athlete-tokens user))
)

(define-read-only (get-consistency-level (user principal))
  (default-to u0 (map-get? consistency-level user))
)

(define-read-only (get-protocol-stats)
  {
    total-workouts-logged: (var-get total-workouts-logged),
    total-tokens-distributed: (var-get total-tokens-distributed)
  }
)

;; Private Functions

(define-private (is-protocol-owner)
  (is-eq tx-sender (var-get protocol-owner))
)
