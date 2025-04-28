;; Assets Management Blockchain System
;; A decentralized application for tracking and managing land ownership documents


;; =====================================================
;; STATE VARIABLES & DATA STRUCTURES
;; =====================================================

;; Main counter for tracking total documents in the system
(define-data-var document-counter uint u0)

;; Primary document storage mapping
(define-map land-documents
  { document-id: uint }
  {
    title: (string-ascii 64),
    owner: principal,
    file-size: uint,
    registration-block: uint,
    description: (string-ascii 128),
    tags: (list 10 (string-ascii 32))
  }
)

;; Permission controls for document access
(define-map document-permissions
  { document-id: uint, user: principal }
  { can-access: bool }
)

;; =====================================================
;; SYSTEM CONFIGURATION & GOVERNANCE
;; =====================================================

;; The administrator of this registry system
(define-constant registry-admin tx-sender)

;; Status codes for transaction responses
(define-constant error-document-not-found (err u301))
(define-constant error-document-already-exists (err u302))
(define-constant error-invalid-title (err u303))
(define-constant error-invalid-document-size (err u304))
(define-constant error-unauthorized-access (err u305))
(define-constant error-not-document-owner (err u306))
(define-constant error-admin-only (err u300))
(define-constant error-visibility-restricted (err u307))
(define-constant error-tag-validation (err u308))

;; =====================================================
;; HELPER FUNCTIONS & VALIDATORS
;; =====================================================

;; Validates if a tag meets system requirements
(define-private (is-valid-tag (tag (string-ascii 32)))
  (and
    (> (len tag) u0)
    (< (len tag) u33)
  )
)

;; Ensures all document tags meet validation criteria
(define-private (validate-tag-collection (tags (list 10 (string-ascii 32))))
  (and
    (> (len tags) u0)
    (<= (len tags) u10)
    (is-eq (len (filter is-valid-tag tags)) (len tags))
  )
)

;; Checks if a document exists in the registry
(define-private (document-exists (document-id uint))
  (is-some (map-get? land-documents { document-id: document-id }))
)

;; Returns the size of a document
(define-private (get-document-size (document-id uint))
  (default-to u0
    (get file-size
      (map-get? land-documents { document-id: document-id })
    )
  )
)

;; Verifies if a user is the owner of a document
(define-private (is-document-owner (document-id uint) (user principal))
  (match (map-get? land-documents { document-id: document-id })
    doc-data (is-eq (get owner doc-data) user)
    false
  )
)

;; =====================================================
;; PUBLIC INTERFACE - DOCUMENT MANAGEMENT
;; =====================================================

;; Creates a new land document record in the registry
(define-public (register-document
  (title-name (string-ascii 64))
  (file-size uint)
  (description-text (string-ascii 128))
  (document-tags (list 10 (string-ascii 32)))
)
  (let
    (
      (document-id (+ (var-get document-counter) u1))
    )
    ;; Input validation checks
    (asserts! (> (len title-name) u0) error-invalid-title)
    (asserts! (< (len title-name) u65) error-invalid-title)
    (asserts! (> file-size u0) error-invalid-document-size)
    (asserts! (< file-size u1000000000) error-invalid-document-size)
    (asserts! (> (len description-text) u0) error-invalid-title)
    (asserts! (< (len description-text) u129) error-invalid-title)
    (asserts! (validate-tag-collection document-tags) error-tag-validation)

    ;; Create the new document record
    (map-insert land-documents
      { document-id: document-id }
      {
        title: title-name,
        owner: tx-sender,
        file-size: file-size,
        registration-block: block-height,
        description: description-text,
        tags: document-tags
      }
    )

    ;; Set initial permissions for document creator
    (map-insert document-permissions
      { document-id: document-id, user: tx-sender }
      { can-access: true }
    )

    ;; Update the document counter
    (var-set document-counter document-id)
    (ok document-id)
  )
)

;; Updates an existing document's metadata
(define-public (update-document
  (document-id uint)
  (new-title (string-ascii 64))
  (new-file-size uint)
  (new-description (string-ascii 128))
  (new-tags (list 10 (string-ascii 32)))
)
  (let
    (
      (document-data (unwrap! (map-get? land-documents { document-id: document-id })
        error-document-not-found))
    )
    ;; Validation checks
    (asserts! (document-exists document-id) error-document-not-found)
    (asserts! (is-eq (get owner document-data) tx-sender) error-not-document-owner)
    (asserts! (> (len new-title) u0) error-invalid-title)
    (asserts! (< (len new-title) u65) error-invalid-title)
    (asserts! (> new-file-size u0) error-invalid-document-size)
    (asserts! (< new-file-size u1000000000) error-invalid-document-size)
    (asserts! (> (len new-description) u0) error-invalid-title)
    (asserts! (< (len new-description) u129) error-invalid-title)
    (asserts! (validate-tag-collection new-tags) error-tag-validation)

    ;; Update the document with new information
    (map-set land-documents
      { document-id: document-id }
      (merge document-data {
        title: new-title,
        file-size: new-file-size,
        description: new-description,
        tags: new-tags
      })
    )
    (ok true)
  )
)

;; =====================================================
;; PUBLIC INTERFACE - OWNERSHIP OPERATIONS
;; =====================================================

;; Transfers document ownership to another principal
(define-public (transfer-document (document-id uint) (new-owner principal))
  (let
    (
      (document-data (unwrap! (map-get? land-documents { document-id: document-id })
        error-document-not-found))
    )
    ;; Verify current ownership
    (asserts! (document-exists document-id) error-document-not-found)
    (asserts! (is-eq (get owner document-data) tx-sender) error-not-document-owner)

    ;; Transfer ownership by updating document record
    (map-set land-documents
      { document-id: document-id }
      (merge document-data { owner: new-owner })
    )
    (ok true)
  )
)

;; Permanently removes a document from the registry
(define-public (deregister-document (document-id uint))
  (let
    (
      (document-data (unwrap! (map-get? land-documents { document-id: document-id })
        error-document-not-found))
    )
    ;; Verify document exists and caller is owner
    (asserts! (document-exists document-id) error-document-not-found)
    (asserts! (is-eq (get owner document-data) tx-sender) error-not-document-owner)

    ;; Remove the document from the registry
    (map-delete land-documents { document-id: document-id })
    (ok true)
  )
)

