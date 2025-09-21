;; dispute-management
;; Contract for managing community disputes and conflict reporting

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-unauthorized (err u100))
(define-constant err-dispute-not-found (err u101))
(define-constant err-invalid-status (err u102))
(define-constant err-invalid-priority (err u103))
(define-constant err-invalid-category (err u104))
(define-constant err-self-dispute (err u105))

;; Data Maps
(define-map disputes
  { dispute-id: uint }
  {
    complainant: principal,
    respondent: principal,
    title: (string-utf8 100),
    description: (string-utf8 1000),
    category: (string-utf8 50),
    priority: (string-utf8 20),
    status: (string-utf8 30),
    evidence-hash: (optional (string-utf8 64)),
    creation-block: uint,
    last-updated: uint,
    is-anonymous: bool,
    location: (optional (string-utf8 100))
  }
)

(define-map dispute-participants
  { dispute-id: uint }
  {
    witnesses: (list 10 principal),
    affected-parties: (list 15 principal),
    support-complainant: uint,
    support-respondent: uint,
    neutral-count: uint
  }
)

(define-map dispute-updates
  { update-id: uint }
  {
    dispute-id: uint,
    updater: principal,
    update-type: (string-utf8 30),
    description: (string-utf8 500),
    timestamp: uint,
    is-public: bool
  }
)

(define-map user-disputes
  { user: principal }
  { dispute-ids: (list 50 uint) }
)

(define-map community-members
  { member: principal }
  {
    reputation-score: uint,
    disputes-filed: uint,
    disputes-involved: uint,
    successful-resolutions: uint,
    registration-block: uint,
    is-active: bool
  }
)

;; Data Variables
(define-data-var next-dispute-id uint u1)
(define-data-var next-update-id uint u1)
(define-data-var total-disputes uint u0)
(define-data-var active-disputes uint u0)
(define-data-var resolved-disputes uint u0)

;; Private Functions
(define-private (is-valid-status (status (string-utf8 30)))
  (or (is-eq status u"submitted")
      (is-eq status u"under-review")
      (is-eq status u"in-mediation")
      (is-eq status u"awaiting-response")
      (is-eq status u"resolved")
      (is-eq status u"closed")
      (is-eq status u"escalated"))
)

(define-private (is-valid-priority (priority (string-utf8 20)))
  (or (is-eq priority u"low")
      (is-eq priority u"medium")
      (is-eq priority u"high")
      (is-eq priority u"urgent"))
)

(define-private (is-valid-category (category (string-utf8 50)))
  (or (is-eq category u"neighbor-dispute")
      (is-eq category u"property-boundary")
      (is-eq category u"noise-complaint")
      (is-eq category u"business-conflict")
      (is-eq category u"community-resources")
      (is-eq category u"harassment")
      (is-eq category u"environmental")
      (is-eq category u"other"))
)

;; Public Functions
(define-public (register-member)
  (begin
    (map-set community-members
      { member: tx-sender }
      {
        reputation-score: u100,
        disputes-filed: u0,
        disputes-involved: u0,
        successful-resolutions: u0,
        registration-block: block-height,
        is-active: true
      }
    )
    (ok true)
  )
)

(define-public (file-dispute
    (respondent principal)
    (title (string-utf8 100))
    (description (string-utf8 1000))
    (category (string-utf8 50))
    (priority (string-utf8 20))
    (is-anonymous bool)
    (location (optional (string-utf8 100)))
    (evidence-hash (optional (string-utf8 64)))
  )
  (let
    (
      (dispute-id (var-get next-dispute-id))
      (complainant-disputes (default-to { dispute-ids: (list) }
        (map-get? user-disputes { user: tx-sender })))
      (respondent-disputes (default-to { dispute-ids: (list) }
        (map-get? user-disputes { user: respondent })))
    )
    (asserts! (not (is-eq tx-sender respondent)) err-self-dispute)
    (asserts! (is-valid-category category) err-invalid-category)
    (asserts! (is-valid-priority priority) err-invalid-priority)
    
    ;; Create dispute
    (map-set disputes
      { dispute-id: dispute-id }
      {
        complainant: tx-sender,
        respondent: respondent,
        title: title,
        description: description,
        category: category,
        priority: priority,
        status: u"submitted",
        evidence-hash: evidence-hash,
        creation-block: block-height,
        last-updated: block-height,
        is-anonymous: is-anonymous,
        location: location
      }
    )
    
    ;; Initialize dispute participants
    (map-set dispute-participants
      { dispute-id: dispute-id }
      {
        witnesses: (list),
        affected-parties: (list),
        support-complainant: u0,
        support-respondent: u0,
        neutral-count: u0
      }
    )
    
    ;; Update user dispute lists
    (map-set user-disputes
      { user: tx-sender }
      { dispute-ids: (unwrap! (as-max-len?
          (append (get dispute-ids complainant-disputes) dispute-id) u50)
        (err u106)) }
    )
    
    (map-set user-disputes
      { user: respondent }
      { dispute-ids: (unwrap! (as-max-len?
          (append (get dispute-ids respondent-disputes) dispute-id) u50)
        (err u107)) }
    )
    
    ;; Update member statistics
    (let
      (
        (complainant-member (default-to {
          reputation-score: u100, disputes-filed: u0, disputes-involved: u0,
          successful-resolutions: u0, registration-block: block-height, is-active: true
        } (map-get? community-members { member: tx-sender })))
        (respondent-member (default-to {
          reputation-score: u100, disputes-filed: u0, disputes-involved: u0,
          successful-resolutions: u0, registration-block: block-height, is-active: true
        } (map-get? community-members { member: respondent })))
      )
      (map-set community-members
        { member: tx-sender }
        (merge complainant-member { disputes-filed: (+ (get disputes-filed complainant-member) u1) })
      )
      (map-set community-members
        { member: respondent }
        (merge respondent-member { disputes-involved: (+ (get disputes-involved respondent-member) u1) })
      )
    )
    
    ;; Update counters
    (var-set next-dispute-id (+ dispute-id u1))
    (var-set total-disputes (+ (var-get total-disputes) u1))
    (var-set active-disputes (+ (var-get active-disputes) u1))
    
    (ok dispute-id)
  )
)

(define-public (update-dispute-status (dispute-id uint) (new-status (string-utf8 30)))
  (let
    (
      (dispute (unwrap! (map-get? disputes { dispute-id: dispute-id }) err-dispute-not-found))
      (update-id (var-get next-update-id))
    )
    (asserts! (is-valid-status new-status) err-invalid-status)
    (asserts! (or (is-eq tx-sender (get complainant dispute))
                  (is-eq tx-sender (get respondent dispute))
                  (is-eq tx-sender contract-owner)) err-unauthorized)
    
    ;; Update dispute status
    (map-set disputes
      { dispute-id: dispute-id }
      (merge dispute {
        status: new-status,
        last-updated: block-height
      })
    )
    
    ;; Log status update
    (map-set dispute-updates
      { update-id: update-id }
      {
        dispute-id: dispute-id,
        updater: tx-sender,
        update-type: u"status-change",
        description: new-status,
        timestamp: block-height,
        is-public: true
      }
    )
    
    ;; Update active/resolved counters
    (if (or (is-eq new-status u"resolved") (is-eq new-status u"closed"))
      (begin
        (var-set active-disputes (- (var-get active-disputes) u1))
        (var-set resolved-disputes (+ (var-get resolved-disputes) u1))
      )
      true
    )
    
    (var-set next-update-id (+ update-id u1))
    (ok true)
  )
)

(define-public (add-witness (dispute-id uint) (witness principal))
  (let
    (
      (dispute (unwrap! (map-get? disputes { dispute-id: dispute-id }) err-dispute-not-found))
      (participants (unwrap! (map-get? dispute-participants { dispute-id: dispute-id }) (err u108)))
      (current-witnesses (get witnesses participants))
    )
    (asserts! (or (is-eq tx-sender (get complainant dispute))
                  (is-eq tx-sender (get respondent dispute))
                  (is-eq tx-sender witness)) err-unauthorized)
    (asserts! (< (len current-witnesses) u10) (err u109))
    
    (map-set dispute-participants
      { dispute-id: dispute-id }
      (merge participants {
        witnesses: (unwrap! (as-max-len? (append current-witnesses witness) u10) (err u110))
      })
    )
    (ok true)
  )
)

(define-public (add-support (dispute-id uint) (support-type (string-utf8 20)))
  (let
    (
      (dispute (unwrap! (map-get? disputes { dispute-id: dispute-id }) err-dispute-not-found))
      (participants (unwrap! (map-get? dispute-participants { dispute-id: dispute-id }) (err u111)))
    )
    (asserts! (not (or (is-eq tx-sender (get complainant dispute))
                       (is-eq tx-sender (get respondent dispute)))) (err u112))
    
    (if (is-eq support-type u"complainant")
      (map-set dispute-participants
        { dispute-id: dispute-id }
        (merge participants {
          support-complainant: (+ (get support-complainant participants) u1)
        })
      )
      (if (is-eq support-type u"respondent")
        (map-set dispute-participants
          { dispute-id: dispute-id }
          (merge participants {
            support-respondent: (+ (get support-respondent participants) u1)
          })
        )
        (map-set dispute-participants
          { dispute-id: dispute-id }
          (merge participants {
            neutral-count: (+ (get neutral-count participants) u1)
          })
        )
      )
    )
    (ok true)
  )
)

(define-public (add-evidence (dispute-id uint) (evidence-hash (string-utf8 64)) (description (string-utf8 500)))
  (let
    (
      (dispute (unwrap! (map-get? disputes { dispute-id: dispute-id }) err-dispute-not-found))
      (update-id (var-get next-update-id))
    )
    (asserts! (or (is-eq tx-sender (get complainant dispute))
                  (is-eq tx-sender (get respondent dispute))) err-unauthorized)
    
    ;; Log evidence update
    (map-set dispute-updates
      { update-id: update-id }
      {
        dispute-id: dispute-id,
        updater: tx-sender,
        update-type: u"evidence-added",
        description: description,
        timestamp: block-height,
        is-public: false
      }
    )
    
    (var-set next-update-id (+ update-id u1))
    (ok true)
  )
)

;; Read Functions
(define-read-only (get-dispute (dispute-id uint))
  (map-get? disputes { dispute-id: dispute-id })
)

(define-read-only (get-dispute-participants (dispute-id uint))
  (map-get? dispute-participants { dispute-id: dispute-id })
)

(define-read-only (get-user-disputes (user principal))
  (map-get? user-disputes { user: user })
)

(define-read-only (get-member-info (member principal))
  (map-get? community-members { member: member })
)

(define-read-only (get-dispute-update (update-id uint))
  (map-get? dispute-updates { update-id: update-id })
)

(define-read-only (get-dispute-stats)
  {
    total-disputes: (var-get total-disputes),
    active-disputes: (var-get active-disputes),
    resolved-disputes: (var-get resolved-disputes),
    next-dispute-id: (var-get next-dispute-id),
    next-update-id: (var-get next-update-id)
  }
)

