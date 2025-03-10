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

;; Asset Management Functions
(define-public (deactivate-asset (asset-id uint))
    ;; Permanently deactivates an asset owned by the sender
    (let ((current-holder (unwrap! (map-get? asset-holder asset-id) error-unauthorized-asset)))
        (asserts! (is-eq tx-sender current-holder) error-unauthorized-asset)
        (asserts! (not (is-asset-deactivated asset-id)) error-asset-deactivated)
        (try! (nft-burn? digital-asset asset-id current-holder))
        (map-set deactivated-assets asset-id true)
        (ok true)))

(define-public (transfer-asset (asset-id uint) (sender principal) (recipient principal))
    ;; Transfers asset ownership from sender to recipient
    (begin
        (asserts! (is-eq recipient tx-sender) error-unauthorized-asset)
        (asserts! (not (is-asset-deactivated asset-id)) error-asset-deactivated)
        (let ((actual-sender (unwrap! (map-get? asset-holder asset-id) error-unauthorized-asset)))
            (asserts! (is-eq actual-sender sender) error-unauthorized-asset)
            (try! (nft-transfer? digital-asset asset-id sender recipient))
            (ok true))))

(define-public (modify-asset-value (asset-id uint) (new-value uint))
    ;; Updates the value associated with a specific asset
    (begin
        (asserts! (does-asset-exist asset-id) error-unauthorized-asset)
        (asserts! (validate-value-amount new-value) error-invalid-value)
        (map-set asset-value asset-id new-value)
        (ok true)))

;; Information Retrieval Functions
(define-read-only (get-asset-value (asset-id uint))
    ;; Retrieves the value associated with an asset
    (ok (map-get? asset-value asset-id)))

(define-read-only (get-asset-holder (asset-id uint))
    ;; Retrieves the current holder of an asset
    (ok (map-get? asset-holder asset-id)))

(define-read-only (get-current-asset-count)
    ;; Retrieves the total number of assets created
    (ok (var-get asset-counter)))

(define-read-only (check-deactivation-status (asset-id uint))
    ;; Checks if an asset has been deactivated
    (ok (is-asset-deactivated asset-id)))

(define-read-only (get-asset-range (start-id uint) (count uint))
    ;; Retrieves information about a range of assets
    (ok (map convert-id-to-details 
        (unwrap-panic (as-max-len? 
            (generate-asset-list start-id count) 
            u100)))))

;; Utility Functions for Asset Listings
(define-private (convert-id-to-details (id uint))
    ;; Converts asset ID to detailed information object
    {
        asset-id: id,
        value: (unwrap-panic (get-asset-value id)),
        holder: (unwrap-panic (get-asset-holder id)),
        deactivated: (unwrap-panic (check-deactivation-status id))
    })

(define-private (generate-asset-list (start uint) (count uint))
    ;; Creates a list of sequential asset IDs
    (map + (list start) (generate-sequence count)))

(define-private (generate-sequence (length uint))
    ;; Utility to generate a sequence of incrementing numbers
    (map - (list length)))
