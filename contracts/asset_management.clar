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
