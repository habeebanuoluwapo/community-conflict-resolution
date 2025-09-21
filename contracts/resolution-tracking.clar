;; resolution-tracking
;; Contract for tracking dispute resolutions and community healing outcomes

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-unauthorized (err u100))
(define-constant err-resolution-not-found (err u101))
(define-constant err-invalid-status (err u102))
(define-constant err-invalid-outcome-type (err u103))
(define-constant err-agreement-not-found (err u104))
(define-constant err-follow-up-not-found (err u105))

;; Data Maps
(define-map dispute-resolutions
  { resolution-id: uint }
  {
    dispute-id: uint,
    resolution-type: (string-utf8 30),
    outcome: (string-utf8 50),
    final-status: (string-utf8 30),
    resolution-date: uint,
    mediator: (optional principal),
    participants: (list 20 principal),
    agreement-terms: (optional (string-utf8 2000)),
    satisfaction-complainant: (optional uint),
    satisfaction-respondent: (optional uint),
    community-impact-score: uint,
    follow-up-required: bool,
    enforcement-mechanism: (optional (string-utf8 200))
  }
)

(define-map resolution-agreements
  { agreement-id: uint }
  {
    resolution-id: uint,
    agreement-text: (string-utf8 2000),
    terms: (list 15 (string-utf8 300)),
    compliance-requirements: (list 10 (string-utf8 200)),
    timeline: (string-utf8 200),
    signatures: (list 20 { signer: principal, timestamp: uint }),
    witness-signatures: (list 10 { witness: principal, timestamp: uint }),
    is-binding: bool,
    effective-date: uint,
    expiration-date: (optional uint)
  }
)

(define-map follow-up-tracking
  { follow-up-id: uint }
  {
    resolution-id: uint,
    follow-up-type: (string-utf8 30),
    scheduled-date: uint,
    completion-date: (optional uint),
    status: (string-utf8 20),
    notes: (optional (string-utf8 500)),
    compliance-level: (optional uint),
    issues-identified: (list 5 (string-utf8 200)),
    next-action-required: (optional (string-utf8 300))
  }
)

(define-map community-healing
  { healing-id: uint }
  {
    dispute-id: uint,
    healing-activities: (list 10 (string-utf8 200)),
    participants: (list 30 principal),
    community-meetings: uint,
    restoration-actions: (list 5 (string-utf8 300)),
    relationship-status: (string-utf8 30),
    community-satisfaction: uint,
    healing-completion-date: (optional uint),
    ongoing-support-needed: bool
  }
)

(define-map outcome-analytics
  { analytics-id: uint }
  {
    dispute-category: (string-utf8 50),
    resolution-method: (string-utf8 30),
    time-to-resolution: uint,
    cost-estimate: uint,
    success-factors: (list 5 (string-utf8 200)),
    challenges-faced: (list 5 (string-utf8 200)),
    lessons-learned: (string-utf8 1000),
    replication-potential: uint
  }
)

(define-map resolution-compliance
  { compliance-id: uint }
  {
    agreement-id: uint,
    compliance-checks: (list 10 { date: uint, status: (string-utf8 20), notes: (string-utf8 300) }),
    violations-reported: uint,
    corrective-actions: (list 5 (string-utf8 300)),
    overall-compliance-rate: uint,
    enforcement-actions: (list 3 (string-utf8 200))
  }
)

;; Data Variables
(define-data-var next-resolution-id uint u1)
(define-data-var next-agreement-id uint u1)
(define-data-var next-follow-up-id uint u1)
(define-data-var next-healing-id uint u1)
(define-data-var next-analytics-id uint u1)
(define-data-var next-compliance-id uint u1)
(define-data-var total-resolutions uint u0)
(define-data-var successful-resolutions uint u0)
(define-data-var community-healing-cases uint u0)

;; Private Functions
(define-private (is-valid-resolution-type (resolution-type (string-utf8 30)))
  (or (is-eq resolution-type u"mediated-agreement")
      (is-eq resolution-type u"community-decision")
      (is-eq resolution-type u"self-resolved")
      (is-eq resolution-type u"arbitration")
      (is-eq resolution-type u"withdrawn")
      (is-eq resolution-type u"escalated"))
)

(define-private (is-valid-outcome (outcome (string-utf8 50)))
  (or (is-eq outcome u"full-resolution")
      (is-eq outcome u"partial-resolution")
      (is-eq outcome u"no-resolution")
      (is-eq outcome u"ongoing-process")
      (is-eq outcome u"case-closed"))
)

(define-private (is-valid-follow-up-type (follow-up-type (string-utf8 30)))
  (or (is-eq follow-up-type u"compliance-check")
      (is-eq follow-up-type u"relationship-review")
      (is-eq follow-up-type u"community-meeting")
      (is-eq follow-up-type u"support-session")
      (is-eq follow-up-type u"enforcement-action"))
)

;; Public Functions
(define-public (record-resolution
    (dispute-id uint)
    (resolution-type (string-utf8 30))
    (outcome (string-utf8 50))
    (final-status (string-utf8 30))
    (mediator (optional principal))
    (participants (list 20 principal))
    (agreement-terms (optional (string-utf8 2000)))
    (community-impact-score uint)
    (follow-up-required bool)
  )
  (let
    (
      (resolution-id (var-get next-resolution-id))
    )
    (asserts! (is-valid-resolution-type resolution-type) err-invalid-outcome-type)
    (asserts! (is-valid-outcome outcome) (err u106))
    (asserts! (<= community-impact-score u100) (err u107))
    
    ;; Record resolution
    (map-set dispute-resolutions
      { resolution-id: resolution-id }
      {
        dispute-id: dispute-id,
        resolution-type: resolution-type,
        outcome: outcome,
        final-status: final-status,
        resolution-date: block-height,
        mediator: mediator,
        participants: participants,
        agreement-terms: agreement-terms,
        satisfaction-complainant: none,
        satisfaction-respondent: none,
        community-impact-score: community-impact-score,
        follow-up-required: follow-up-required,
        enforcement-mechanism: none
      }
    )
    
    ;; Update counters
    (var-set next-resolution-id (+ resolution-id u1))
    (var-set total-resolutions (+ (var-get total-resolutions) u1))
    
    ;; Update success counter
    (if (or (is-eq outcome u"full-resolution") (is-eq outcome u"partial-resolution"))
      (var-set successful-resolutions (+ (var-get successful-resolutions) u1))
      true
    )
    
    (ok resolution-id)
  )
)

(define-public (create-resolution-agreement
    (resolution-id uint)
    (agreement-text (string-utf8 2000))
    (terms (list 15 (string-utf8 300)))
    (compliance-requirements (list 10 (string-utf8 200)))
    (timeline (string-utf8 200))
    (is-binding bool)
    (expiration-date (optional uint))
  )
  (let
    (
      (agreement-id (var-get next-agreement-id))
      (resolution (unwrap! (map-get? dispute-resolutions { resolution-id: resolution-id }) err-resolution-not-found))
    )
    (asserts! (or (is-some (index-of? (get participants resolution) tx-sender))
                  (is-eq tx-sender contract-owner)) err-unauthorized)
    
    ;; Create agreement
    (map-set resolution-agreements
      { agreement-id: agreement-id }
      {
        resolution-id: resolution-id,
        agreement-text: agreement-text,
        terms: terms,
        compliance-requirements: compliance-requirements,
        timeline: timeline,
        signatures: (list),
        witness-signatures: (list),
        is-binding: is-binding,
        effective-date: block-height,
        expiration-date: expiration-date
      }
    )
    
    (var-set next-agreement-id (+ agreement-id u1))
    (ok agreement-id)
  )
)

(define-public (sign-agreement (agreement-id uint))
  (let
    (
      (agreement (unwrap! (map-get? resolution-agreements { agreement-id: agreement-id }) err-agreement-not-found))
      (resolution (unwrap! (map-get? dispute-resolutions { resolution-id: (get resolution-id agreement) }) err-resolution-not-found))
      (current-signatures (get signatures agreement))
    )
    (asserts! (is-some (index-of? (get participants resolution) tx-sender)) err-unauthorized)
    (asserts! (< (len current-signatures) u20) (err u108))
    
    ;; Add signature
    (map-set resolution-agreements
      { agreement-id: agreement-id }
      (merge agreement {
        signatures: (unwrap! (as-max-len? 
          (append current-signatures { signer: tx-sender, timestamp: block-height }) u20)
          (err u109))
      })
    )
    (ok true)
  )
)

(define-public (schedule-follow-up
    (resolution-id uint)
    (follow-up-type (string-utf8 30))
    (scheduled-date uint)
    (notes (optional (string-utf8 500)))
  )
  (let
    (
      (follow-up-id (var-get next-follow-up-id))
      (resolution (unwrap! (map-get? dispute-resolutions { resolution-id: resolution-id }) err-resolution-not-found))
    )
    (asserts! (is-valid-follow-up-type follow-up-type) (err u110))
    (asserts! (or (is-some (get mediator resolution))
                  (is-eq tx-sender contract-owner)) err-unauthorized)
    
    ;; Schedule follow-up
    (map-set follow-up-tracking
      { follow-up-id: follow-up-id }
      {
        resolution-id: resolution-id,
        follow-up-type: follow-up-type,
        scheduled-date: scheduled-date,
        completion-date: none,
        status: u"scheduled",
        notes: notes,
        compliance-level: none,
        issues-identified: (list),
        next-action-required: none
      }
    )
    
    (var-set next-follow-up-id (+ follow-up-id u1))
    (ok follow-up-id)
  )
)

(define-public (complete-follow-up
    (follow-up-id uint)
    (compliance-level uint)
    (issues-identified (list 5 (string-utf8 200)))
    (next-action-required (optional (string-utf8 300)))
    (notes (string-utf8 500))
  )
  (let
    (
      (follow-up (unwrap! (map-get? follow-up-tracking { follow-up-id: follow-up-id }) err-follow-up-not-found))
    )
    (asserts! (<= compliance-level u100) (err u111))
    (asserts! (or (is-eq tx-sender contract-owner)
                  (is-eq (get status follow-up) u"scheduled")) err-unauthorized)
    
    ;; Complete follow-up
    (map-set follow-up-tracking
      { follow-up-id: follow-up-id }
      (merge follow-up {
        completion-date: (some block-height),
        status: u"completed",
        notes: (some notes),
        compliance-level: (some compliance-level),
        issues-identified: issues-identified,
        next-action-required: next-action-required
      })
    )
    (ok true)
  )
)

(define-public (initiate-community-healing
    (dispute-id uint)
    (healing-activities (list 10 (string-utf8 200)))
    (participants (list 30 principal))
    (restoration-actions (list 5 (string-utf8 300)))
  )
  (let
    (
      (healing-id (var-get next-healing-id))
    )
    (asserts! (> (len participants) u0) (err u112))
    
    ;; Initiate healing process
    (map-set community-healing
      { healing-id: healing-id }
      {
        dispute-id: dispute-id,
        healing-activities: healing-activities,
        participants: participants,
        community-meetings: u0,
        restoration-actions: restoration-actions,
        relationship-status: u"healing-in-progress",
        community-satisfaction: u0,
        healing-completion-date: none,
        ongoing-support-needed: true
      }
    )
    
    (var-set next-healing-id (+ healing-id u1))
    (var-set community-healing-cases (+ (var-get community-healing-cases) u1))
    (ok healing-id)
  )
)

(define-public (record-satisfaction-rating
    (resolution-id uint)
    (rating uint)
    (is-complainant bool)
  )
  (let
    (
      (resolution (unwrap! (map-get? dispute-resolutions { resolution-id: resolution-id }) err-resolution-not-found))
    )
    (asserts! (and (>= rating u1) (<= rating u5)) (err u113))
    (asserts! (is-some (index-of? (get participants resolution) tx-sender)) err-unauthorized)
    
    ;; Update satisfaction rating
    (if is-complainant
      (map-set dispute-resolutions
        { resolution-id: resolution-id }
        (merge resolution { satisfaction-complainant: (some rating) })
      )
      (map-set dispute-resolutions
        { resolution-id: resolution-id }
        (merge resolution { satisfaction-respondent: (some rating) })
      )
    )
    (ok true)
  )
)

(define-public (update-community-healing-status
    (healing-id uint)
    (community-meetings uint)
    (relationship-status (string-utf8 30))
    (community-satisfaction uint)
    (is-completed bool)
  )
  (let
    (
      (healing (unwrap! (map-get? community-healing { healing-id: healing-id }) (err u114)))
    )
    (asserts! (<= community-satisfaction u100) (err u115))
    (asserts! (or (is-some (index-of? (get participants healing) tx-sender))
                  (is-eq tx-sender contract-owner)) err-unauthorized)
    
    ;; Update healing status
    (map-set community-healing
      { healing-id: healing-id }
      (merge healing {
        community-meetings: community-meetings,
        relationship-status: relationship-status,
        community-satisfaction: community-satisfaction,
        healing-completion-date: (if is-completed (some block-height) none),
        ongoing-support-needed: (not is-completed)
      })
    )
    (ok true)
  )
)

;; Read Functions
(define-read-only (get-resolution (resolution-id uint))
  (map-get? dispute-resolutions { resolution-id: resolution-id })
)

(define-read-only (get-resolution-agreement (agreement-id uint))
  (map-get? resolution-agreements { agreement-id: agreement-id })
)

(define-read-only (get-follow-up (follow-up-id uint))
  (map-get? follow-up-tracking { follow-up-id: follow-up-id })
)

(define-read-only (get-community-healing (healing-id uint))
  (map-get? community-healing { healing-id: healing-id })
)

(define-read-only (get-resolution-stats)
  {
    total-resolutions: (var-get total-resolutions),
    successful-resolutions: (var-get successful-resolutions),
    success-rate: (if (> (var-get total-resolutions) u0)
                    (/ (* (var-get successful-resolutions) u100) (var-get total-resolutions))
                    u0),
    community-healing-cases: (var-get community-healing-cases),
    next-resolution-id: (var-get next-resolution-id),
    next-agreement-id: (var-get next-agreement-id),
    next-follow-up-id: (var-get next-follow-up-id),
    next-healing-id: (var-get next-healing-id)
  }
)

