;; Equipment Registration Contract
;; Records details of emergency communication gear

;; Data Variables
(define-data-var equipment-counter uint u0)

;; Data Maps
(define-map equipment
  { equipment-id: uint }
  {
    owner: principal,
    name: (string-utf8 100),
    type: (string-utf8 50),
    frequency-range: (string-utf8 50),
    power-source: (string-utf8 50),
    battery-life: uint,
    range: uint,
    weather-resistant: bool,
    last-maintenance: uint,
    status: (string-utf8 20),
    registration-date: uint
  }
)

(define-map owner-equipment
  { owner: principal }
  { equipment-ids: (list 100 uint) }
)

(define-map equipment-type
  { type: (string-utf8 50) }
  { equipment-ids: (list 100 uint) }
)

;; Register new emergency communication equipment
(define-public (register-equipment
    (name (string-utf8 100))
    (type (string-utf8 50))
    (frequency-range (string-utf8 50))
    (power-source (string-utf8 50))
    (battery-life uint)
    (range uint)
    (weather-resistant bool)
    (last-maintenance uint))
  (let ((equipment-id (var-get equipment-counter)))
    (begin
      ;; Store the equipment information
      (map-set equipment
        { equipment-id: equipment-id }
        {
          owner: tx-sender,
          name: name,
          type: type,
          frequency-range: frequency-range,
          power-source: power-source,
          battery-life: battery-life,
          range: range,
          weather-resistant: weather-resistant,
          last-maintenance: last-maintenance,
          status: u"available",
          registration-date: block-height
        }
      )

      ;; Update owner-to-equipment mapping
      (let ((owner-list (default-to { equipment-ids: (list) } (map-get? owner-equipment { owner: tx-sender }))))
        (map-set owner-equipment
          { owner: tx-sender }
          { equipment-ids: (unwrap-panic (as-max-len? (append (get equipment-ids owner-list) equipment-id) u100)) }
        )
      )

      ;; Update type-to-equipment mapping
      (let ((type-list (default-to { equipment-ids: (list) } (map-get? equipment-type { type: type }))))
        (map-set equipment-type
          { type: type }
          { equipment-ids: (unwrap-panic (as-max-len? (append (get equipment-ids type-list) equipment-id) u100)) }
        )
      )

      ;; Increment counter and return equipment ID
      (var-set equipment-counter (+ equipment-id u1))
      (ok equipment-id)
    )
  )
)

;; Update equipment status
(define-public (update-equipment-status
    (equipment-id uint)
    (status (string-utf8 20)))
  (let ((equipment-data (map-get? equipment { equipment-id: equipment-id })))
    (if (and (is-some equipment-data) (is-eq tx-sender (get owner (unwrap-panic equipment-data))))
      (begin
        (map-set equipment
          { equipment-id: equipment-id }
          (merge (unwrap-panic equipment-data) {
            status: status
          })
        )
        (ok true)
      )
      (err u1) ;; Not owner or equipment doesn't exist
    )
  )
)

;; Update equipment maintenance date
(define-public (update-maintenance
    (equipment-id uint)
    (maintenance-date uint))
  (let ((equipment-data (map-get? equipment { equipment-id: equipment-id })))
    (if (and (is-some equipment-data) (is-eq tx-sender (get owner (unwrap-panic equipment-data))))
      (begin
        (map-set equipment
          { equipment-id: equipment-id }
          (merge (unwrap-panic equipment-data) {
            last-maintenance: maintenance-date
          })
        )
        (ok true)
      )
      (err u1) ;; Not owner or equipment doesn't exist
    )
  )
)

;; Get equipment details by ID
(define-read-only (get-equipment (equipment-id uint))
  (map-get? equipment { equipment-id: equipment-id })
)

;; Get all equipment owned by a user
(define-read-only (get-owner-equipment (owner principal))
  (default-to { equipment-ids: (list) } (map-get? owner-equipment { owner: owner }))
)

;; Get all equipment of a specific type
(define-read-only (get-equipment-by-type (type (string-utf8 50)))
  (default-to { equipment-ids: (list) } (map-get? equipment-type { type: type }))
)

;; Get the total number of registered equipment
(define-read-only (get-equipment-count)
  (var-get equipment-counter)
)

