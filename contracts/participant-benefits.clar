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

;; Contract Initialization
(begin
    ;; Sets initial system state
    (var-set asset-counter u0))

;; Extended Asset Information Functions
(define-read-only (get-total-assets-created)
    ;; Returns the total count of assets created in the system
    (ok (var-get asset-counter)))

(define-read-only (check-sufficient-value (asset-id uint) (value-threshold uint))
    ;; Checks if the asset has sufficient value to meet a threshold
    (let ((asset-value-amount (unwrap-panic (map-get? asset-value asset-id))))
        (ok (>= asset-value-amount value-threshold))))

(define-read-only (get-asset-notes (asset-id uint))
    ;; Returns additional notes stored for an asset
    (ok (map-get? asset-notes asset-id)))

(define-read-only (can-deactivate-asset (asset-id uint) (user principal))
    ;; Determines if a user can deactivate a specific asset
    (let ((current-holder (unwrap-panic (map-get? asset-holder asset-id))))
        (ok (and (is-eq user current-holder)
                 (not (is-asset-deactivated asset-id))))))

(define-read-only (is-valid-asset (asset-id uint))
    ;; Checks if the asset exists and is active
    (let ((exists (is-some (map-get? asset-holder asset-id)))
          (deactivated (is-asset-deactivated asset-id)))
        (ok (and exists (not deactivated)))))

(define-read-only (get-total-active-assets)
    ;; Returns the total count of active assets
    (ok (var-get asset-counter)))

(define-read-only (can-transfer-asset (asset-id uint) (user principal))
    ;; Checks if the asset can be transferred by the user
    (let ((current-holder (unwrap-panic (map-get? asset-holder asset-id))))
        (ok (and
             (is-eq user current-holder)
             (not (is-asset-deactivated asset-id))))))

(define-read-only (get-asset-details (asset-id uint))
    ;; Returns notes associated with a specific asset
    (ok (map-get? asset-notes asset-id)))

(define-read-only (asset-exists (asset-id uint))
    ;; Checks if the asset ID exists in the system
    (ok (is-some (map-get? asset-holder asset-id))))

(define-read-only (get-asset-info (asset-id uint))
    ;; Returns the value and holder of an asset
    (let ((holder (unwrap-panic (map-get? asset-holder asset-id)))
          (value (unwrap-panic (map-get? asset-value asset-id))))
        (ok { holder: holder, value: value })))

(define-read-only (get-asset-value-or-default (asset-id uint))
    ;; Returns the value associated with an asset, or 0 if the asset does not exist
    (ok (default-to u0 (map-get? asset-value asset-id))))

(define-read-only (get-asset-status (asset-id uint))
    ;; Returns the active/inactive status of an asset
    (ok (is-asset-deactivated asset-id)))

(define-read-only (verify-asset-holder (asset-id uint) (holder principal))
    ;; Checks if the given principal is the holder of the asset
    (ok (is-eq holder (unwrap-panic (map-get? asset-holder asset-id)))))

(define-read-only (get-total-issued-count)
    ;; Returns the total count of assets issued
    (ok (var-get asset-counter)))

(define-read-only (get-holder-of-asset (asset-id uint))
    ;; Returns the holder of an asset by its ID
    (ok (map-get? asset-holder asset-id)))

(define-read-only (get-value-of-asset (asset-id uint))
    ;; Returns the value associated with an asset
    (ok (map-get? asset-value asset-id)))

(define-read-only (is-asset-transferable (asset-id uint) (user principal))
    ;; Checks if the user owns the asset and if it can be transferred
    (let ((current-holder (unwrap-panic (map-get? asset-holder asset-id))))
      (ok (and (is-eq user current-holder)
               (not (is-asset-deactivated asset-id))))))

(define-read-only (is-asset-deactivatable (asset-id uint) (user principal))
    ;; Checks if the asset can be deactivated by the user (must be owned by user and not deactivated)
    (let ((current-holder (unwrap-panic (map-get? asset-holder asset-id))))
      (ok (and (is-eq user current-holder)
               (not (is-asset-deactivated asset-id))))))

(define-read-only (get-latest-asset-id-or-zero)
    ;; Returns the last asset ID or 0 if no assets exist
    (ok (var-get asset-counter)))

(define-read-only (is-asset-value-valid (asset-id uint))
    ;; Checks if the value associated with the asset is valid (greater than or equal to 1)
    (let ((value (unwrap-panic (map-get? asset-value asset-id))))
      (ok (>= value u1))))

;; Contract Initialization
(begin
    ;; Initializes contract state variables
    (var-set asset-counter u0))

;; Advanced Asset Management Functions
(define-public (reclaim-asset (asset-id uint))
    ;; Reclaims an asset, transferring ownership back to the administrator (admin only)
    (begin
        (asserts! (is-eq tx-sender contract-administrator) error-unauthorized-admin)
        (asserts! (does-asset-exist asset-id) error-unauthorized-asset)
        (asserts! (not (is-asset-deactivated asset-id)) error-asset-deactivated)
        (map-set asset-holder asset-id contract-administrator)
        (ok true)))

(define-public (reduce-asset-value (asset-id uint) (value-amount uint))
    ;; Reduces value from an asset (admin only)
    (begin
        (asserts! (is-eq tx-sender contract-administrator) error-unauthorized-admin)
        (asserts! (does-asset-exist asset-id) error-unauthorized-asset)
        (let ((current-value (unwrap! (map-get? asset-value asset-id) error-unauthorized-asset)))
            (asserts! (>= current-value value-amount) error-insufficient-value)
            (map-set asset-value asset-id (- current-value value-amount))
            (ok true))))

(define-public (mark-asset-inactive (asset-id uint))
    ;; Marks an asset as inactive, preventing further transfers
    (begin
        (asserts! (is-eq tx-sender contract-administrator) error-unauthorized-admin)
        (asserts! (does-asset-exist asset-id) error-unauthorized-asset)
        (map-set deactivated-assets asset-id true)
        (ok true)))

(define-public (combine-assets (source-asset uint) (target-asset uint))
    ;; Combines values from one asset to another
    (begin
        (asserts! (does-asset-exist source-asset) error-unauthorized-asset)
        (asserts! (does-asset-exist target-asset) error-unauthorized-asset)
        (let ((source-value (unwrap! (map-get? asset-value source-asset) error-unauthorized-asset))
              (target-value (unwrap! (map-get? asset-value target-asset) error-unauthorized-asset)))
            (map-set asset-value target-asset (+ target-value source-value))
            (map-delete asset-value source-asset)
            (map-delete asset-holder source-asset)
            (ok true))))

(define-public (suspend-asset (asset-id uint))
    ;; Suspends an asset so it cannot be transferred or updated
    (begin
        (asserts! (validate-asset-holder asset-id tx-sender) error-unauthorized-asset)
        (asserts! (not (is-asset-deactivated asset-id)) error-asset-deactivated)
        (map-set deactivated-assets asset-id true)
        (ok true)))

(define-public (reactivate-asset (asset-id uint))
    ;; Reactivates a previously suspended asset
    (begin
        (asserts! (validate-asset-holder asset-id tx-sender) error-unauthorized-asset)
        (map-set deactivated-assets asset-id false)
        (ok true)))

(define-public (claim-asset-ownership (asset-id uint))
    ;; Claims ownership of an asset
    (begin
        (asserts! (does-asset-exist asset-id) error-unauthorized-asset)
        (map-set asset-holder asset-id tx-sender)
        (ok true)))

(define-public (mark-asset-dormant (asset-id uint))
    ;; Marks an asset as dormant (sets a special note)
    (begin
        (asserts! (validate-asset-holder asset-id tx-sender) error-unauthorized-asset)
        (map-set asset-notes asset-id "dormant")
        (ok true)))

(define-public (restore-asset-active (asset-id uint))
    ;; Restores a dormant asset to active status
    (begin
        (asserts! (validate-asset-holder asset-id tx-sender) error-unauthorized-asset)
        (map-delete asset-notes asset-id)
        (ok true)))

(define-public (add-asset-information (asset-id uint) (information (string-ascii 256)))
    ;; Adds additional information to an asset
    (begin
        (asserts! (does-asset-exist asset-id) error-unauthorized-asset)
        (asserts! (<= (len information) u256) error-invalid-value)
        (map-set asset-notes asset-id information)
        (ok true)))

(define-public (remove-asset-information (asset-id uint))
    ;; Removes information for an asset
    (begin
        (asserts! (does-asset-exist asset-id) error-unauthorized-asset)
        (map-delete asset-notes asset-id)
        (ok true)))

(define-public (redeem-asset-value (asset-id uint))
    ;; Allows the holder of an asset to redeem its value
    (begin
        (asserts! (validate-asset-holder asset-id tx-sender) error-unauthorized-asset)
        (map-set asset-value asset-id u0)
        (ok true)))

(define-public (purge-asset-information (asset-id uint))
    ;; Clears information of a specific asset (admin only)
    (begin
        (asserts! (does-asset-exist asset-id) error-unauthorized-asset)
        (asserts! (is-eq tx-sender contract-administrator) error-unauthorized-admin)
        (map-delete asset-notes asset-id)
        (ok true)))

(define-public (consolidate-asset-values (source-id uint) (target-id uint))
    ;; Transfers all value from one asset to another (admin only)
    (begin
        (asserts! (does-asset-exist source-id) error-unauthorized-asset)
        (asserts! (does-asset-exist target-id) error-unauthorized-asset)
        (asserts! (is-eq tx-sender contract-administrator) error-unauthorized-admin)
        (let ((source-value (unwrap-panic (map-get? asset-value source-id)))
              (target-value (unwrap-panic (map-get? asset-value target-id))))
            (map-set asset-value target-id (+ source-value target-value))
            (map-set asset-value source-id u0)
            (ok true))))

(define-public (restore-deactivated-asset (asset-id uint))
    ;; Restores a deactivated asset (admin only)
    (begin
        (asserts! (does-asset-exist asset-id) error-unauthorized-asset)
        (asserts! (is-asset-deactivated asset-id) error-invalid-value)
        (asserts! (is-eq tx-sender contract-administrator) error-unauthorized-admin)
        (map-set deactivated-assets asset-id false)
        (ok true)))



