
;; title: SidechainBridge
;; version: 1.0.0
;; summary: Cross-chain AMM liquidity pool connecting Bitcoin sidechains with Stacks
;; description: A decentralized bridge enabling seamless asset transfers and AMM functionality between Bitcoin sidechains and Stacks blockchain

;; traits
;;

;; token definitions
;;

;; constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INSUFFICIENT_BALANCE (err u101))
(define-constant ERR_INVALID_AMOUNT (err u102))
(define-constant ERR_POOL_NOT_EXISTS (err u103))
(define-constant ERR_SLIPPAGE_EXCEEDED (err u104))
(define-constant ERR_INVALID_SIDECHAIN (err u105))
(define-constant ERR_BRIDGE_PAUSED (err u106))
(define-constant ERR_INVALID_PROOF (err u107))

;; Minimum liquidity to prevent division by zero
(define-constant MIN_LIQUIDITY u1000)

;; Fee basis points (0.3% = 30 bp)
(define-constant FEE_BASIS_POINTS u30)
(define-constant BASIS_POINTS_DENOMINATOR u10000)

;; data vars
(define-data-var bridge-paused bool false)
(define-data-var total-pools uint u0)
(define-data-var protocol-fee-recipient principal CONTRACT_OWNER)

;; data maps
;; Pool information: poolId -> pool data
(define-map pools uint {
    token-a: principal,
    token-b: principal,
    reserve-a: uint,
    reserve-b: uint,
    total-supply: uint,
    k-last: uint
})

;; User liquidity positions: (poolId, user) -> LP token balance
(define-map liquidity-positions {pool-id: uint, user: principal} uint)

;; Supported sidechains: sidechain-id -> sidechain info
(define-map supported-sidechains uint {
    name: (string-ascii 32),
    active: bool,
    min-confirmations: uint
})

;; Bridge transactions: txId -> bridge data
(define-map bridge-transactions (buff 32) {
    from-chain: uint,
    to-chain: uint,
    sender: principal,
    recipient: principal,
    amount: uint,
    token: principal,
    status: (string-ascii 20),
    timestamp: uint
})

;; Cross-chain proofs: txId -> proof verification
(define-map cross-chain-proofs (buff 32) {
    verified: bool,
    verifier: principal,
    timestamp: uint
})

;; public functions

;; Initialize a new liquidity pool
(define-public (create-pool (token-a principal) (token-b principal) (initial-a uint) (initial-b uint))
    (let ((pool-id (+ (var-get total-pools) u1)))
        (asserts! (> initial-a u0) ERR_INVALID_AMOUNT)
        (asserts! (> initial-b u0) ERR_INVALID_AMOUNT)
        (asserts! (not (var-get bridge-paused)) ERR_BRIDGE_PAUSED)

        ;; Store pool data
        (map-set pools pool-id {
            token-a: token-a,
            token-b: token-b,
            reserve-a: initial-a,
            reserve-b: initial-b,
            total-supply: (* initial-a initial-b),
            k-last: (* initial-a initial-b)
        })

        ;; Mint initial LP tokens to creator
        (map-set liquidity-positions {pool-id: pool-id, user: tx-sender} (* initial-a initial-b))

        ;; Update total pools counter
        (var-set total-pools pool-id)

        (ok pool-id)
    )
)

;; Add liquidity to existing pool
(define-public (add-liquidity (pool-id uint) (amount-a uint) (amount-b uint) (min-liquidity uint))
    (let ((pool (unwrap! (map-get? pools pool-id) ERR_POOL_NOT_EXISTS)))
        (asserts! (> amount-a u0) ERR_INVALID_AMOUNT)
        (asserts! (> amount-b u0) ERR_INVALID_AMOUNT)
        (asserts! (not (var-get bridge-paused)) ERR_BRIDGE_PAUSED)

        (let ((reserve-a (get reserve-a pool))
              (reserve-b (get reserve-b pool))
              (total-supply (get total-supply pool))
              (liquidity (min (/ (* amount-a total-supply) reserve-a)
                             (/ (* amount-b total-supply) reserve-b))))

            (asserts! (>= liquidity min-liquidity) ERR_SLIPPAGE_EXCEEDED)

            ;; Update pool reserves
            (map-set pools pool-id (merge pool {
                reserve-a: (+ reserve-a amount-a),
                reserve-b: (+ reserve-b amount-b),
                total-supply: (+ total-supply liquidity)
            }))

            ;; Update user LP balance
            (let ((current-balance (default-to u0 (map-get? liquidity-positions {pool-id: pool-id, user: tx-sender}))))
                (map-set liquidity-positions {pool-id: pool-id, user: tx-sender} (+ current-balance liquidity))
            )

            (ok liquidity)
        )
    )
)

;; Remove liquidity from pool
(define-public (remove-liquidity (pool-id uint) (liquidity uint) (min-amount-a uint) (min-amount-b uint))
    (let ((pool (unwrap! (map-get? pools pool-id) ERR_POOL_NOT_EXISTS))
          (user-balance (default-to u0 (map-get? liquidity-positions {pool-id: pool-id, user: tx-sender}))))

        (asserts! (>= user-balance liquidity) ERR_INSUFFICIENT_BALANCE)
        (asserts! (> liquidity u0) ERR_INVALID_AMOUNT)

        (let ((total-supply (get total-supply pool))
              (reserve-a (get reserve-a pool))
              (reserve-b (get reserve-b pool))
              (amount-a (/ (* liquidity reserve-a) total-supply))
              (amount-b (/ (* liquidity reserve-b) total-supply)))

            (asserts! (>= amount-a min-amount-a) ERR_SLIPPAGE_EXCEEDED)
            (asserts! (>= amount-b min-amount-b) ERR_SLIPPAGE_EXCEEDED)

            ;; Update pool reserves
            (map-set pools pool-id (merge pool {
                reserve-a: (- reserve-a amount-a),
                reserve-b: (- reserve-b amount-b),
                total-supply: (- total-supply liquidity)
            }))

            ;; Update user LP balance
            (map-set liquidity-positions {pool-id: pool-id, user: tx-sender} (- user-balance liquidity))

            (ok {amount-a: amount-a, amount-b: amount-b})
        )
    )
)

;; Swap tokens in AMM pool
(define-public (swap (pool-id uint) (token-in principal) (amount-in uint) (min-amount-out uint))
    (let ((pool (unwrap! (map-get? pools pool-id) ERR_POOL_NOT_EXISTS)))
        (asserts! (> amount-in u0) ERR_INVALID_AMOUNT)
        (asserts! (not (var-get bridge-paused)) ERR_BRIDGE_PAUSED)

        (let ((token-a (get token-a pool))
              (token-b (get token-b pool))
              (reserve-a (get reserve-a pool))
              (reserve-b (get reserve-b pool)))

            (if (is-eq token-in token-a)
                ;; Swapping token-a for token-b
                (let ((amount-out (get-amount-out amount-in reserve-a reserve-b)))
                    (asserts! (>= amount-out min-amount-out) ERR_SLIPPAGE_EXCEEDED)

                    ;; Update reserves
                    (map-set pools pool-id (merge pool {
                        reserve-a: (+ reserve-a amount-in),
                        reserve-b: (- reserve-b amount-out)
                    }))

                    (ok amount-out)
                )
                ;; Swapping token-b for token-a
                (let ((amount-out (get-amount-out amount-in reserve-b reserve-a)))
                    (asserts! (>= amount-out min-amount-out) ERR_SLIPPAGE_EXCEEDED)

                    ;; Update reserves
                    (map-set pools pool-id (merge pool {
                        reserve-a: (- reserve-a amount-out),
                        reserve-b: (+ reserve-b amount-in)
                    }))

                    (ok amount-out)
                )
            )
        )
    )
)

;; Initiate cross-chain bridge transfer
(define-public (bridge-transfer (to-chain uint) (recipient principal) (amount uint) (token principal))
    (let ((tx-id (keccak256 (concat (concat (unwrap-panic (to-consensus-buff? tx-sender))
                                           (unwrap-panic (to-consensus-buff? block-height)))
                                   (unwrap-panic (to-consensus-buff? amount))))))

        (asserts! (> amount u0) ERR_INVALID_AMOUNT)
        (asserts! (not (var-get bridge-paused)) ERR_BRIDGE_PAUSED)
        (asserts! (is-some (map-get? supported-sidechains to-chain)) ERR_INVALID_SIDECHAIN)

        ;; Record bridge transaction
        (map-set bridge-transactions tx-id {
            from-chain: u0, ;; Stacks chain ID
            to-chain: to-chain,
            sender: tx-sender,
            recipient: recipient,
            amount: amount,
            token: token,
            status: "pending",
            timestamp: block-height
        })

        (ok tx-id)
    )
)

;; Complete cross-chain transfer with proof verification
(define-public (complete-bridge-transfer (tx-id (buff 32)) (proof (buff 1024)))
    (let ((bridge-tx (unwrap! (map-get? bridge-transactions tx-id) ERR_INVALID_PROOF)))
        (asserts! (is-eq (get status bridge-tx) "pending") ERR_INVALID_PROOF)
        (asserts! (not (var-get bridge-paused)) ERR_BRIDGE_PAUSED)

        ;; Verify cross-chain proof (simplified - in production would use merkle proofs)
        (asserts! (verify-cross-chain-proof tx-id proof) ERR_INVALID_PROOF)

        ;; Update transaction status
        (map-set bridge-transactions tx-id (merge bridge-tx {status: "completed"}))

        ;; Record proof verification
        (map-set cross-chain-proofs tx-id {
            verified: true,
            verifier: tx-sender,
            timestamp: block-height
        })

        (ok true)
    )
)

;; Admin function to add supported sidechain
(define-public (add-sidechain (sidechain-id uint) (name (string-ascii 32)) (min-confirmations uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)

        (map-set supported-sidechains sidechain-id {
            name: name,
            active: true,
            min-confirmations: min-confirmations
        })

        (ok true)
    )
)

;; Admin function to pause/unpause bridge
(define-public (set-bridge-paused (paused bool))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
        (var-set bridge-paused paused)
        (ok true)
    )
)

;; read only functions

;; Get pool information
(define-read-only (get-pool (pool-id uint))
    (map-get? pools pool-id)
)

;; Get user's liquidity position
(define-read-only (get-liquidity-position (pool-id uint) (user principal))
    (default-to u0 (map-get? liquidity-positions {pool-id: pool-id, user: user}))
)

;; Calculate amount out for swap (constant product formula with fees)
(define-read-only (get-amount-out (amount-in uint) (reserve-in uint) (reserve-out uint))
    (let ((amount-in-with-fee (- amount-in (/ (* amount-in FEE_BASIS_POINTS) BASIS_POINTS_DENOMINATOR)))
          (numerator (* amount-in-with-fee reserve-out))
          (denominator (+ reserve-in amount-in-with-fee)))
        (/ numerator denominator)
    )
)

;; Get bridge transaction status
(define-read-only (get-bridge-transaction (tx-id (buff 32)))
    (map-get? bridge-transactions tx-id)
)

;; Get supported sidechain info
(define-read-only (get-sidechain (sidechain-id uint))
    (map-get? supported-sidechains sidechain-id)
)

;; Check if bridge is paused
(define-read-only (is-bridge-paused)
    (var-get bridge-paused)
)

;; Get total number of pools
(define-read-only (get-total-pools)
    (var-get total-pools)
)

;; private functions

;; Simplified cross-chain proof verification (placeholder)
(define-private (verify-cross-chain-proof (tx-id (buff 32)) (proof (buff 1024)))
    ;; In production, this would implement proper merkle proof verification
    ;; For now, we'll use a simplified check
    (> (len proof) u32)
)

;; Helper function to get minimum of two numbers
(define-private (min (a uint) (b uint))
    (if (<= a b) a b)
)
