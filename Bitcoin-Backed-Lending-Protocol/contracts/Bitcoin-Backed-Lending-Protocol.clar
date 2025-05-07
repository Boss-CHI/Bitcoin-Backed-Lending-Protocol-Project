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
