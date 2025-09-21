;; mediation-coordination
;; Contract for coordinating mediation sessions and managing mediators

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-unauthorized (err u100))
(define-constant err-mediator-not-found (err u101))
(define-constant err-session-not-found (err u102))
(define-constant err-invalid-status (err u103))
(define-constant err-invalid-outcome (err u104))
(define-constant err-session-conflict (err u105))

;; Data Maps
(define-map mediators
  { mediator: principal }
  {
    name: (string-utf8 100),
    specializations: (string-utf8 200),
    experience-years: uint,
    certification-level: (string-utf8 30),
    availability-schedule: (string-utf8 200),
    max-concurrent-cases: uint,
    current-active-cases: uint,
    total-cases-handled: uint,
    success-rate: uint,
    average-rating: uint,
    total-ratings: uint,
    registration-block: uint,
    is-active: bool
  }
)

(define-map mediation-sessions
  { session-id: uint }
  {
    dispute-id: uint,
    mediator: principal,
    complainant: principal,
    respondent: principal,
    session-type: (string-utf8 30),
    scheduled-block: uint,
    actual-start-block: (optional uint),
    duration-minutes: (optional uint),
    status: (string-utf8 30),
    outcome: (optional (string-utf8 50)),
    notes: (optional (string-utf8 1000)),
    agreements-reached: (list 10 (string-utf8 200)),
    follow-up-required: bool,
    next-session-block: (optional uint)
  }
)

(define-map mediator-assignments
  { assignment-id: uint }
  {
    mediator: principal,
    dispute-id: uint,
    assignment-block: uint,
    status: (string-utf8 20),
    estimated-sessions: uint,
    completed-sessions: uint,
    last-session-block: (optional uint)
  }
)

(define-map session-participants
  { session-id: uint }
  {
    attendees: (list 20 principal),
    observers: (list 10 principal),
    support-persons: (list 5 principal),
    attendance-confirmed: (list 20 bool)
  }
)

(define-map mediator-schedules
  { mediator: principal, date-block: uint }
  {
    available-slots: (list 8 uint),
    booked-slots: (list 8 uint),
    blocked-times: (list 4 { start: uint, end: uint })
  }
)

;; Data Variables
(define-data-var next-session-id uint u1)
(define-data-var next-assignment-id uint u1)
(define-data-var total-sessions uint u0)
(define-data-var active-sessions uint u0)
(define-data-var completed-sessions uint u0)
(define-data-var successful-mediations uint u0)

;; Private Functions
(define-private (is-valid-session-status (status (string-utf8 30)))
  (or (is-eq status u"scheduled")
      (is-eq status u"in-progress")
      (is-eq status u"completed")
      (is-eq status u"cancelled")
      (is-eq status u"postponed")
      (is-eq status u"no-show"))
)

(define-private (is-valid-outcome (outcome (string-utf8 50)))
  (or (is-eq outcome u"full-agreement")
      (is-eq outcome u"partial-agreement")
      (is-eq outcome u"no-agreement")
      (is-eq outcome u"referral-required")
      (is-eq outcome u"legal-escalation")
      (is-eq outcome u"withdrawn"))
)

(define-private (is-valid-session-type (session-type (string-utf8 30)))
  (or (is-eq session-type u"initial-consultation")
      (is-eq session-type u"joint-session")
      (is-eq session-type u"separate-caucus")
      (is-eq session-type u"follow-up")
      (is-eq session-type u"agreement-signing"))
)

;; Public Functions
(define-public (register-mediator
    (name (string-utf8 100))
    (specializations (string-utf8 200))
    (experience-years uint)
    (certification-level (string-utf8 30))
    (availability-schedule (string-utf8 200))
    (max-concurrent-cases uint)
  )
  (begin
    (map-set mediators
      { mediator: tx-sender }
      {
        name: name,
        specializations: specializations,
        experience-years: experience-years,
        certification-level: certification-level,
        availability-schedule: availability-schedule,
        max-concurrent-cases: max-concurrent-cases,
        current-active-cases: u0,
        total-cases-handled: u0,
        success-rate: u0,
        average-rating: u0,
        total-ratings: u0,
        registration-block: block-height,
        is-active: true
      }
    )
    (ok true)
  )
)

(define-public (assign-mediator (dispute-id uint) (mediator-principal principal) (estimated-sessions uint))
  (let
    (
      (assignment-id (var-get next-assignment-id))
      (mediator-info (unwrap! (map-get? mediators { mediator: mediator-principal }) err-mediator-not-found))
    )
    (asserts! (< (get current-active-cases mediator-info) (get max-concurrent-cases mediator-info)) (err u106))
    (asserts! (get is-active mediator-info) (err u107))
    
    ;; Create assignment
    (map-set mediator-assignments
      { assignment-id: assignment-id }
      {
        mediator: mediator-principal,
        dispute-id: dispute-id,
        assignment-block: block-height,
        status: u"active",
        estimated-sessions: estimated-sessions,
        completed-sessions: u0,
        last-session-block: none
      }
    )
    
    ;; Update mediator's active cases count
    (map-set mediators
      { mediator: mediator-principal }
      (merge mediator-info {
        current-active-cases: (+ (get current-active-cases mediator-info) u1),
        total-cases-handled: (+ (get total-cases-handled mediator-info) u1)
      })
    )
    
    (var-set next-assignment-id (+ assignment-id u1))
    (ok assignment-id)
  )
)

(define-public (schedule-mediation-session
    (dispute-id uint)
    (mediator-principal principal)
    (complainant principal)
    (respondent principal)
    (session-type (string-utf8 30))
    (scheduled-block uint)
  )
  (let
    (
      (session-id (var-get next-session-id))
      (mediator-info (unwrap! (map-get? mediators { mediator: mediator-principal }) err-mediator-not-found))
    )
    (asserts! (is-valid-session-type session-type) (err u108))
    (asserts! (> scheduled-block block-height) (err u109))
    (asserts! (or (is-eq tx-sender mediator-principal)
                  (is-eq tx-sender contract-owner)) err-unauthorized)
    
    ;; Create mediation session
    (map-set mediation-sessions
      { session-id: session-id }
      {
        dispute-id: dispute-id,
        mediator: mediator-principal,
        complainant: complainant,
        respondent: respondent,
        session-type: session-type,
        scheduled-block: scheduled-block,
        actual-start-block: none,
        duration-minutes: none,
        status: u"scheduled",
        outcome: none,
        notes: none,
        agreements-reached: (list),
        follow-up-required: false,
        next-session-block: none
      }
    )
    
    ;; Initialize session participants
    (map-set session-participants
      { session-id: session-id }
      {
        attendees: (list complainant respondent),
        observers: (list),
        support-persons: (list),
        attendance-confirmed: (list false false)
      }
    )
    
    ;; Update counters
    (var-set next-session-id (+ session-id u1))
    (var-set total-sessions (+ (var-get total-sessions) u1))
    (var-set active-sessions (+ (var-get active-sessions) u1))
    
    (ok session-id)
  )
)

(define-public (start-mediation-session (session-id uint))
  (let
    (
      (session (unwrap! (map-get? mediation-sessions { session-id: session-id }) err-session-not-found))
    )
    (asserts! (is-eq tx-sender (get mediator session)) err-unauthorized)
    (asserts! (is-eq (get status session) u"scheduled") (err u110))
    
    (map-set mediation-sessions
      { session-id: session-id }
      (merge session {
        status: u"in-progress",
        actual-start-block: (some block-height)
      })
    )
    (ok true)
  )
)

(define-public (complete-mediation-session
    (session-id uint)
    (duration-minutes uint)
    (outcome (string-utf8 50))
    (notes (string-utf8 1000))
    (agreements-reached (list 10 (string-utf8 200)))
    (follow-up-required bool)
  )
  (let
    (
      (session (unwrap! (map-get? mediation-sessions { session-id: session-id }) err-session-not-found))
      (mediator-info (unwrap! (map-get? mediators { mediator: (get mediator session) }) err-mediator-not-found))
    )
    (asserts! (is-eq tx-sender (get mediator session)) err-unauthorized)
    (asserts! (is-eq (get status session) u"in-progress") (err u111))
    (asserts! (is-valid-outcome outcome) err-invalid-outcome)
    
    ;; Complete session
    (map-set mediation-sessions
      { session-id: session-id }
      (merge session {
        status: u"completed",
        duration-minutes: (some duration-minutes),
        outcome: (some outcome),
        notes: (some notes),
        agreements-reached: agreements-reached,
        follow-up-required: follow-up-required
      })
    )
    
    ;; Update counters
    (var-set active-sessions (- (var-get active-sessions) u1))
    (var-set completed-sessions (+ (var-get completed-sessions) u1))
    
    ;; Update success counter if agreement reached
    (if (or (is-eq outcome u"full-agreement") (is-eq outcome u"partial-agreement"))
      (var-set successful-mediations (+ (var-get successful-mediations) u1))
      true
    )
    
    (ok true)
  )
)

(define-public (add-session-participant
    (session-id uint)
    (participant principal)
    (participant-type (string-utf8 20))
  )
  (let
    (
      (session (unwrap! (map-get? mediation-sessions { session-id: session-id }) err-session-not-found))
      (participants (unwrap! (map-get? session-participants { session-id: session-id }) (err u112)))
    )
    (asserts! (is-eq tx-sender (get mediator session)) err-unauthorized)
    
    (if (is-eq participant-type u"observer")
      (begin
        (map-set session-participants
          { session-id: session-id }
          (merge participants {
            observers: (unwrap! (as-max-len? (append (get observers participants) participant) u10) (err u113))
          })
        )
        (ok true)
      )
      (if (is-eq participant-type u"support")
        (begin
          (map-set session-participants
            { session-id: session-id }
            (merge participants {
              support-persons: (unwrap! (as-max-len? (append (get support-persons participants) participant) u5) (err u114))
            })
          )
          (ok true)
        )
        (err u115)
      )
    )
  )
)

(define-public (confirm-attendance (session-id uint))
  (let
    (
      (session (unwrap! (map-get? mediation-sessions { session-id: session-id }) err-session-not-found))
      (participants (unwrap! (map-get? session-participants { session-id: session-id }) (err u116)))
      (attendees (get attendees participants))
    )
    (asserts! (or (is-eq tx-sender (get complainant session))
                  (is-eq tx-sender (get respondent session))) err-unauthorized)
    
    ;; Find participant index and mark attendance
    (let
      (
        (participant-index (index-of? attendees tx-sender))
      )
      (if (is-some participant-index)
        (begin
          ;; Update attendance confirmation (simplified logic)
          (ok true)
        )
        (err u117)
      )
    )
  )
)

(define-public (rate-mediator (session-id uint) (rating uint))
  (let
    (
      (session (unwrap! (map-get? mediation-sessions { session-id: session-id }) err-session-not-found))
      (mediator-info (unwrap! (map-get? mediators { mediator: (get mediator session) }) err-mediator-not-found))
      (current-avg (get average-rating mediator-info))
      (total-ratings (get total-ratings mediator-info))
      (new-total-ratings (+ total-ratings u1))
      (new-average (/ (+ (* current-avg total-ratings) rating) new-total-ratings))
    )
    (asserts! (or (is-eq tx-sender (get complainant session))
                  (is-eq tx-sender (get respondent session))) err-unauthorized)
    (asserts! (is-eq (get status session) u"completed") (err u118))
    (asserts! (and (>= rating u1) (<= rating u5)) (err u119))
    
    ;; Update mediator rating
    (map-set mediators
      { mediator: (get mediator session) }
      (merge mediator-info {
        average-rating: new-average,
        total-ratings: new-total-ratings
      })
    )
    (ok true)
  )
)

(define-public (update-mediator-availability (mediator-principal principal) (new-schedule (string-utf8 200)))
  (let
    (
      (mediator-info (unwrap! (map-get? mediators { mediator: mediator-principal }) err-mediator-not-found))
    )
    (asserts! (is-eq tx-sender mediator-principal) err-unauthorized)
    
    (map-set mediators
      { mediator: mediator-principal }
      (merge mediator-info { availability-schedule: new-schedule })
    )
    (ok true)
  )
)

;; Read Functions
(define-read-only (get-mediator (mediator-principal principal))
  (map-get? mediators { mediator: mediator-principal })
)

(define-read-only (get-mediation-session (session-id uint))
  (map-get? mediation-sessions { session-id: session-id })
)

(define-read-only (get-mediator-assignment (assignment-id uint))
  (map-get? mediator-assignments { assignment-id: assignment-id })
)

(define-read-only (get-session-participants (session-id uint))
  (map-get? session-participants { session-id: session-id })
)

(define-read-only (get-mediation-stats)
  {
    total-sessions: (var-get total-sessions),
    active-sessions: (var-get active-sessions),
    completed-sessions: (var-get completed-sessions),
    successful-mediations: (var-get successful-mediations),
    success-rate: (if (> (var-get completed-sessions) u0)
                    (/ (* (var-get successful-mediations) u100) (var-get completed-sessions))
                    u0),
    next-session-id: (var-get next-session-id),
    next-assignment-id: (var-get next-assignment-id)
  }
)

