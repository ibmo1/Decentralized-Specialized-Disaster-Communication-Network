;; Operator Certification Contract
;; Validates training in emergency protocols

;; Data Variables
(define-data-var certification-counter uint u0)

;; Data Maps
(define-map certifications
  { certification-id: uint }
  {
    operator: principal,
    certification-type: (string-utf8 50),
    issuer: principal,
    issue-date: uint,
    expiration-date: uint,
    training-hours: uint,
    skills: (list 10 (string-utf8 50)),
    status: (string-utf8 20),
    verification-hash: (buff 32)
  }
)

(define-map operator-certifications
  { operator: principal }
  { certification-ids: (list 100 uint) }
)

(define-map certification-type-operators
  { certification-type: (string-utf8 50) }
  { certification-ids: (list 100 uint) }
)

(define-map issuers
  { issuer-id: principal }
  { is-active: bool }
)

;; Register as an issuer
(define-public (register-issuer)
  (begin
    (map-set issuers
      { issuer-id: tx-sender }
      { is-active: true }
    )
    (ok true)
  )
)

;; Issue a certification
(define-public (issue-certification
    (operator principal)
    (certification-type (string-utf8 50))
    (expiration-date uint)
    (training-hours uint)
    (skills (list 10 (string-utf8 50)))
    (verification-hash (buff 32)))
  (let ((certification-id (var-get certification-counter))
        (issuer-data (map-get? issuers { issuer-id: tx-sender })))
    (if (and (is-some issuer-data) (get is-active (unwrap-panic issuer-data)))
      (begin
        ;; Store the certification
        (map-set certifications
          { certification-id: certification-id }
          {
            operator: operator,
            certification-type: certification-type,
            issuer: tx-sender,
            issue-date: block-height,
            expiration-date: expiration-date,
            training-hours: training-hours,
            skills: skills,
            status: u"active",
            verification-hash: verification-hash
          }
        )

        ;; Update operator-to-certification mapping
        (let ((operator-list (default-to { certification-ids: (list) } (map-get? operator-certifications { operator: operator }))))
          (map-set operator-certifications
            { operator: operator }
            { certification-ids: (unwrap-panic (as-max-len? (append (get certification-ids operator-list) certification-id) u100)) }
          )
        )

        ;; Update certification-type-to-operators mapping
        (let ((type-list (default-to { certification-ids: (list) } (map-get? certification-type-operators { certification-type: certification-type }))))
          (map-set certification-type-operators
            { certification-type: certification-type }
            { certification-ids: (unwrap-panic (as-max-len? (append (get certification-ids type-list) certification-id) u100)) }
          )
        )

        ;; Increment counter and return certification ID
        (var-set certification-counter (+ certification-id u1))
        (ok certification-id)
      )
      (err u1) ;; Not an active issuer
    )
  )
)

;; Revoke a certification
(define-public (revoke-certification (certification-id uint))
  (let ((certification-data (map-get? certifications { certification-id: certification-id })))
    (if (and (is-some certification-data) (is-eq tx-sender (get issuer (unwrap-panic certification-data))))
      (begin
        (map-set certifications
          { certification-id: certification-id }
          (merge (unwrap-panic certification-data) {
            status: u"revoked"
          })
        )
        (ok true)
      )
      (err u1) ;; Not the issuer or certification doesn't exist
    )
  )
)

;; Check if a certification is valid
(define-read-only (is-certification-valid (certification-id uint))
  (let ((certification-data (map-get? certifications { certification-id: certification-id })))
    (if (is-some certification-data)
      (and
        (is-eq (get status (unwrap-panic certification-data)) u"active")
        (< block-height (get expiration-date (unwrap-panic certification-data)))
      )
      false
    )
  )
)

;; Get certification details
(define-read-only (get-certification (certification-id uint))
  (map-get? certifications { certification-id: certification-id })
)

;; Get all certifications for an operator
(define-read-only (get-operator-certifications (operator principal))
  (default-to { certification-ids: (list) } (map-get? operator-certifications { operator: operator }))
)

;; Get all certifications of a specific type
(define-read-only (get-certifications-by-type (certification-type (string-utf8 50)))
  (default-to { certification-ids: (list) } (map-get? certification-type-operators { certification-type: certification-type }))
)

;; Check if a user is an issuer
(define-read-only (is-issuer (user principal))
  (let ((issuer-data (map-get? issuers { issuer-id: user })))
    (if (is-some issuer-data)
      (get is-active (unwrap-panic issuer-data))
      false
    )
  )
)

;; Get the total number of certifications
(define-read-only (get-certification-count)
  (var-get certification-counter)
)

