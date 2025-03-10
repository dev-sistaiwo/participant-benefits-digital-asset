;; Participant Benefits Digital Asset Contract
;; This smart contract implements a digital reward system where participants earn tokenized benefits
;; represented as non-fungible tokens. The system allows for creating, transferring, and managing
;; digital assets with associated value metrics. The contract supports individual and bulk operations
;; while maintaining security through proper access controls and validation checks.

;; System Parameters
(define-constant contract-administrator tx-sender) ;; Administrator address with special privileges
(define-constant error-unauthorized-admin (err u200)) ;; Error code for non-admin actions
(define-constant error-unauthorized-asset (err u201)) ;; Error code for unauthorized asset access
(define-constant error-invalid-value (err u202)) ;; Error code for invalid value entries
(define-constant error-insufficient-value (err u203)) ;; Error code for insufficient value
(define-constant error-asset-deactivated (err u204)) ;; Error code for deactivated assets
(define-constant error-value-exists (err u205)) ;; Error code when value already assigned
(define-constant bulk-operation-limit u100) ;; Maximum assets in a bulk operation

;; Core Storage
(define-non-fungible-token digital-asset uint) ;; Digital asset token definition
(define-data-var asset-counter uint u0) ;; Counter for asset identification

;; Asset Tracking Storage
(define-map asset-holder uint principal) ;; Links assets to their current holders
(define-map asset-value uint uint) ;; Stores value associated with each asset
(define-map deactivated-assets uint bool) ;; Tracks deactivated assets
(define-map asset-notes uint (string-ascii 256)) ;; Additional information about assets

;; Helper Functions - Internal Use
(define-private (validate-asset-holder (asset-id uint) (user principal))
    ;; Verifies if user is the legitimate holder of the specified asset
    (is-eq user (unwrap! (map-get? asset-holder asset-id) false)))

(define-private (validate-value-amount (amount uint))
    ;; Ensures value amount meets minimum requirements
    (>= amount u1))

(define-private (is-asset-deactivated (asset-id uint))
    ;; Checks deactivation status of an asset
    (default-to false (map-get? deactivated-assets asset-id)))

(define-private (does-asset-exist (asset-id uint))
    ;; Verifies existence of an asset in the system
    (is-some (map-get? asset-holder asset-id)))

(define-private (create-asset (amount uint))
    ;; Creates new asset with assigned value amount and registers ownership
    (let ((next-id (+ (var-get asset-counter) u1)))
        (asserts! (validate-value-amount amount) error-invalid-value)
        (try! (nft-mint? digital-asset next-id tx-sender))
        (map-set asset-value next-id amount)
        (map-set asset-holder next-id tx-sender)
        (var-set asset-counter next-id)
        (ok next-id)))

;; Administrative Functions
(define-public (create-single-asset (amount uint))
    ;; Creates a single asset with specified value (admin only)
    (begin
        (asserts! (is-eq tx-sender contract-administrator) error-unauthorized-admin)
        (asserts! (validate-value-amount amount) error-invalid-value)
        (create-asset amount)))

(define-public (create-multiple-assets (amount-list (list 100 uint)))
    ;; Creates multiple assets in one transaction (admin only)
    (let ((operation-size (len amount-list)))
        (begin
            (asserts! (is-eq tx-sender contract-administrator) error-unauthorized-admin)
            (asserts! (<= operation-size bulk-operation-limit) error-invalid-value)
            (asserts! (> operation-size u0) error-invalid-value)
            (ok (fold process-bulk-creation amount-list (list))))))

(define-private (process-bulk-creation (amount uint) (previous-ids (list 100 uint)))
    ;; Processes each asset in the bulk creation operation
    (match (create-asset amount)
        success (unwrap-panic (as-max-len? (append previous-ids success) u100))
        error previous-ids))

