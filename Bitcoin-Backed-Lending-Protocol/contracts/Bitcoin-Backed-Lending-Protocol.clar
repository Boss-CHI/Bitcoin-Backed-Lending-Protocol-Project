;; Constants and Error Codes
(define-constant ERR_UNAUTHORIZED u1)
(define-constant ERR_INSUFFICIENT_COLLATERAL u2)
(define-constant ERR_HEALTH_FACTOR_TOO_LOW u3)
(define-constant ERR_RESERVE_INSUFFICIENT u4)
(define-constant ERR_AMOUNT_TOO_LARGE u5)
(define-constant ERR_INVALID_TOKEN u6)
(define-constant ERR_PROTOCOL_PAUSED u7)
(define-constant ERR_LIQUIDATION_FAILED u8)
(define-constant ERR_INVALID_PARAMETER u9)
(define-constant ERR_ORACLE_FAILURE u10)
(define-constant ERR_INSUFFICIENT_BORROW_BALANCE u11)
(define-constant ERR_INSUFFICIENT_REPAY_ALLOWANCE u12)

;; Protocol configurations
(define-constant CONTRACT_OWNER tx-sender)
(define-constant PROTOCOL_FEE_PERCENTAGE u3) ;; 0.3% protocol fee
(define-constant LIQUIDATION_BONUS_PERCENTAGE u10) ;; 10% bonus for liquidators
(define-constant MIN_HEALTH_FACTOR u11000) ;; 1.10 with 10000 as base
(define-constant LIQUIDATION_THRESHOLD u15000) ;; 1.50 with 10000 as base
(define-constant GRACE_PERIOD_BLOCKS u144) ;; ~24 hours (assuming 10 min block time)

;; Data Maps
(define-map user-vaults
  { user: principal, token-id: uint }
  {
    collateral-amount: uint,
    borrowed-amount: uint,
    interest-index: uint,
    last-update-block-height: uint
  }
)

(define-map supported-tokens
  { token-id: uint }
  {
    token-contract: principal,
    token-name: (string-ascii 32),
    ltv-ratio: uint, ;; Loan-to-Value ratio (base 10000)
    liquidation-threshold: uint, ;; Liquidation threshold (base 10000)
    is-collateral: bool,
    is-borrowable: bool,
    total-supplied: uint,
    total-borrowed: uint,
    reserve-factor: uint, ;; Percentage of interest that goes to reserves (base 10000)
    interest-rate-model: (string-ascii 10) ;; Reference to interest rate model (linear, jump-rate, etc.)
  }
)

(define-map interest-rate-models
  { model-id: (string-ascii 10) }
  {
    base-rate: uint, ;; Base interest rate (base 10000)
    rate-multiplier: uint, ;; Rate multiplier for utilization (base 10000)
    optimal-utilization: uint, ;; Optimal utilization point (base 10000)
    excess-multiplier: uint ;; Multiplier for rates above optimal utilization (base 10000)
  }
)

(define-map price-oracle
  { token-id: uint }
  {
    price: uint, ;; USD price with 8 decimals
    last-update-time: uint,
    source: (string-ascii 32)
  }
)

(define-map protocol-state
  { field: (string-ascii 32) }
  { value: bool }
)

(define-map cumulative-interest-index
  { token-id: uint }
  {
    index: uint, ;; Starts at 10^8
    last-update-block-height: uint
  }
)

(define-map protocol-reserves
  { token-id: uint }
  { amount: uint }
)

;; Data variables
(define-data-var protocol-paused bool false)
(define-data-var oracle-contract principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
(define-data-var treasury-address principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
(define-data-var liquidator-contract principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
(define-data-var token-counter uint u0)

;; Private functions
(define-private (is-contract-owner)
  (is-eq tx-sender CONTRACT_OWNER)
)

(define-private (is-authorized-contract (caller principal))
  (or
    (is-eq caller CONTRACT_OWNER)
    (is-eq caller (var-get oracle-contract))
    (is-eq caller (var-get liquidator-contract))
  )
)

;; Add or update interest rate model
(define-public (set-interest-rate-model (model-id (string-ascii 10))
                                        (base-rate uint)
                                        (rate-multiplier uint)
                                        (optimal-utilization uint)
                                        (excess-multiplier uint))
  (begin
    (asserts! (is-contract-owner) (err ERR_UNAUTHORIZED))
    (asserts! (<= base-rate u10000) (err ERR_INVALID_PARAMETER)) 
    (asserts! (<= optimal-utilization u10000) (err ERR_INVALID_PARAMETER))
    
    (map-set interest-rate-models
      { model-id: model-id }
      {
        base-rate: base-rate,
        rate-multiplier: rate-multiplier,
        optimal-utilization: optimal-utilization,
        excess-multiplier: excess-multiplier
      })
    (ok true)
  )
)

;; Update oracle price
(define-public (update-price (token-id uint) (price uint) (source (string-ascii 32)))
  (begin
    (asserts! (is-authorized-contract tx-sender) (err ERR_UNAUTHORIZED))
    (map-set price-oracle
      { token-id: token-id }
      { 
        price: price, 
        last-update-time: stacks-block-height, 
        source: source 
      })
    (ok true)
  )
)

;; NEW ERROR CODES
(define-constant ERR_VAULT_NOT_FOUND u13)
(define-constant ERR_FLASH_LOAN_NOT_REPAID u14)
(define-constant ERR_WITHDRAWAL_COOL_DOWN u15)
(define-constant ERR_GOVERNANCE_PROPOSAL_EXISTS u16)
(define-constant ERR_GOVERNANCE_VOTE_ENDED u17)
(define-constant ERR_ALREADY_VOTED u18)

;; NEW PROTOCOL CONFIGURATIONS
(define-constant FLASH_LOAN_FEE_PERCENTAGE u9) ;; 0.9% flash loan fee
(define-constant WITHDRAWAL_COOL_DOWN_BLOCKS u36) ;; ~6 hours cool down period
(define-constant GOVERNANCE_VOTING_PERIOD_BLOCKS u1008) ;; ~7 days voting period
(define-constant MIN_PROPOSAL_THRESHOLD u100000000) ;; Minimum token amount to create proposal
(define-constant QUORUM_THRESHOLD u400000000) ;; Minimum votes for a proposal to pass (40%)

;; NEW DATA VARIABLES
(define-data-var flash-loan-counter uint u0)
(define-data-var governance-proposal-counter uint u0)
(define-data-var governance-token-id uint u0)
(define-data-var emergency-admin principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
(define-data-var staking-reward-rate uint u10) ;; 0.1% per block (base 10000)
(define-data-var referral-bonus-percentage uint u200) ;; 2% bonus (base 10000)

;; NEW PRIVATE FUNCTIONS
(define-private (is-emergency-admin)
  (is-eq tx-sender (var-get emergency-admin))
)

(define-private (calculate-flash-loan-fee (amount uint))
  (/ (* amount FLASH_LOAN_FEE_PERCENTAGE) u10000)
)

(define-private (get-token-contract (token-id uint))
  (get token-contract (default-to 
    { 
      token-contract: 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM,
      token-name: "",
      ltv-ratio: u0,
      liquidation-threshold: u0,
      is-collateral: false,
      is-borrowable: false,
      total-supplied: u0,
      total-borrowed: u0,
      reserve-factor: u0,
      interest-rate-model: ""
    }
    (map-get? supported-tokens { token-id: token-id })))
)

;; Set emergency admin
(define-public (set-emergency-admin (new-admin principal))
  (begin
    (asserts! (is-contract-owner) (err ERR_UNAUTHORIZED))
    (var-set emergency-admin new-admin)
    (ok true)
  )
)

;; Emergency pause protocol
(define-public (emergency-pause)
  (begin
    (asserts! (or (is-contract-owner) (is-emergency-admin)) (err ERR_UNAUTHORIZED))
    (var-set protocol-paused true)
    (ok true)
  )
)

;; Emergency unpause protocol
(define-public (emergency-unpause)
  (begin
    (asserts! (is-contract-owner) (err ERR_UNAUTHORIZED))
    (var-set protocol-paused false)
    (ok true)
  )
)


;; NEW ERROR CODES
(define-constant ERR_SAFETY_MODULE_LOCKED u19)
(define-constant ERR_REWARDS_CLAIM_FAILED u20)
(define-constant ERR_REFERRAL_ALREADY_REGISTERED u21)
(define-constant ERR_INSUFFICIENT_STAKE u22)
(define-constant ERR_BRIDGE_INSUFFICIENT_LIQUIDITY u23)
(define-constant ERR_ZAPPING_FAILED u24)
(define-constant ERR_ASSET_CAP_REACHED u25)
(define-constant ERR_CREDIT_DELEGATION_LIMIT_EXCEEDED u26)

(define-constant SAFETY_MODULE_LOCKUP_BLOCKS u4320) ;; ~30 days lockup period
(define-constant REWARDS_DISTRIBUTION_FREQUENCY u144) ;; ~24 hours for rewards distribution
(define-constant MAX_ASSET_CAP_PERCENTAGE u8000) ;; 80% of total supply as max cap (base 10000)
(define-constant CROSS_CHAIN_BRIDGE_FEE u5) ;; 0.05% bridge fee (base 10000)
(define-constant CREDIT_DELEGATION_MAX_RATIO u5000) ;; 50% of collateral can be delegated (base 10000)
(define-constant ZAPPING_SLIPPAGE_TOLERANCE u100) ;; 1% slippage tolerance for zapping (base 10000)

(define-map safety-module-staking
  { user: principal }
  {
    staked-amount: uint,
    lock-until-block: uint,
    reward-index: uint,
    last-claim-block-height: uint
  }
)

(define-map governance-proposals
  { proposal-id: uint }
  {
    proposer: principal,
    title: (string-ascii 64),
    description-hash: (buff 32),
    start-block-height: uint,
    end-block-height: uint,
    execution-block-height: uint,
    votes-for: uint,
    votes-against: uint,
    executed: bool,
    target-contract: (optional principal),
    function-to-call: (optional (string-ascii 128)),
    function-args: (optional (list 10 (buff 256)))
  }
)

(define-map governance-votes
  { proposal-id: uint, voter: principal }
  {
    vote-amount: uint,
    vote-direction: bool, ;; true for yes, false for no
    vote-block-height: uint
  }
)

(define-map referral-program
  { referrer: principal }
  {
    total-referrals: uint,
    total-volume: uint,
    total-rewards: uint,
    last-claim-block-height: uint
  }
)

