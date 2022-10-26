
;; ballot

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Constants
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(define-constant CONTRACT-OWNER tx-sender)
;; Errors
(define-constant ERR-NOT-STARTED (err u1001))
(define-constant ERR-ENDED (err u1002))
(define-constant ERR-ALREADY-VOTED (err u1003))
(define-constant ERR-FAILED-STRATEGY (err u1004))
(define-constant ERR-NOT-VOTED (err u1005))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; data maps and vars
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(define-data-var title (string-utf8 512) u"")
(define-data-var description (string-utf8 512) u"")
(define-data-var voting-system (string-ascii 512) "")
(define-data-var start uint u0)
(define-data-var end uint u0)
(define-map token-ids-map {token-id: uint} {user: principal, vote-id: uint})
(define-map btc-holder-map {domain: (buff 20), namespace: (buff 48)} {user: principal, vote-id: uint})
(define-map results {id: (string-ascii 36)} {count: uint, name: (string-utf8 256)} )
(define-map users {id: principal} {id: uint, vote: (list 2 (string-ascii 36)), volume: (list 2 uint), voting-power: uint})
(define-map register {id: uint} {user: principal, vote: (list 2 (string-ascii 36)), volume: (list 2 uint), voting-power: uint})
(define-data-var total uint u0)
(define-data-var total-votes uint u0)
(define-data-var options (list 2 (string-ascii 36)) (list))
(define-data-var temp-voting-power uint u0)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; private functions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(define-private (get-voting-power-by-bns-holder (domain (buff 20)) (namespace (buff 48)))
    (let
        (
            (bns-owner (get owner (unwrap-panic (contract-call? 'SP000000000000000000002Q6VF78.bns name-resolve domain namespace))))
        )

        (if (is-eq tx-sender bns-owner)
            (match (map-get? btc-holder-map {domain: domain, namespace: namespace})
                result
                    u0
                u1
            )
            u0
        )
    )
)

(define-private (validate-nft-ownership (token-id uint))
    (let
        (
            (vote-id (+ u1 (var-get total)))
            (nft-owner-optional (unwrap-panic (contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.contract get-owner token-id)))
        )

        (match nft-owner-optional
            nft-owner 
                (if (is-eq tx-sender nft-owner)
                    (match (map-get? token-ids-map {token-id: token-id})
                        result
                            u0
                        (if (map-set token-ids-map {token-id: token-id} {user: tx-sender, vote-id: vote-id})                        
                            u1
                            u0
                        )
                    )
                    u0
                )
            u0
        )
    )
)

(define-private (get-voting-power-by-nft-holdings (token-ids (list 60000 uint)))
    (fold + (map validate-nft-ownership token-ids) u0)
)

(define-private (get-voting-power-by-stx-holdings)
    (let
        (
            (stx-balance (stx-get-balance tx-sender))
        )
        (if (> stx-balance u0)
            (/ stx-balance u1000000)
            stx-balance
        )
    )    
)

(define-read-only (get-voting-power-by-ft-holdings)
    (let
        (
            (ft-balance (unwrap-panic (contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.contract get-balance tx-sender)))
            (ft-decimals (unwrap-panic (contract-call? 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM.contract get-decimals)))
        )

        (if (> ft-balance u0)
            (if (> ft-decimals u0)
                (/ ft-balance (pow u10 ft-decimals))
                ft-balance
            )
            ft-balance
        )
    )
)

(define-private (have-i-voted)
    (match (map-get? users {id: tx-sender})
        success true
        false
    )
)

(define-private (fold-boolean (left bool) (right bool))
    (and (is-eq left true) (is-eq right true))
)

(define-private (check-volume (each-volume uint))
    (> each-volume u0)
)

(define-private (validate-vote-volume (volume (list 2 uint)))
    (begin
        (fold fold-boolean (map check-volume volume) true)
    )
)

(define-private (get-volume-by-voting-power (volume uint))
    (var-get temp-voting-power)
)

(define-private (get-pow-value (volume uint))
    (pow volume u2)
)

(define-private (process-my-vote (option-id (string-ascii 36)) (volume uint))
    (match (map-get? results {id: option-id})
        result (let
                (
                    (new-count-tuple {count: (+ volume (get count result))})
                )

                ;; Capture the vote
                (map-set results {id: option-id} (merge result new-count-tuple))

                ;; Return
                true
            )
        false
    )
)

(define-private (get-single-result (option-id (string-ascii 36)))
    (let 
        (
            (volume (default-to u0 (get count (map-get? results {id: option-id}))))
        )

        ;; Return volume
        volume
    )
)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; public functions for all
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(define-public (cast-my-vote (vote (list 2 (string-ascii 36))) (volume (list 2 uint))
    (bns (string-ascii 256)) (domain (buff 20)) (namespace (buff 48)) (token-ids (list 60000 uint))
    )
    (let
        (
            (vote-id (+ u1 (var-get total)))
            ;; Strategy applied
            ;; (voting-power (get-voting-power-by-bns-holder domain namespace))
            ;; (voting-power (get-voting-power-by-nft-holdings token-ids))
            ;; (voting-power (get-voting-power-by-stx-holdings))
            ;; (voting-power (get-voting-power-by-ft-holdings))

            ;; No strategy
            ;; FPTP and Block voting - No strategy
            ;; (voting-power u1)

            ;; Quadratic - No strategy
            ;; (voting-power (fold + (map get-pow-value volume) u0))

            ;; Weighted voting - No strategy
            (voting-power (fold + volume u0))

            ;; FPTP and Block voting
            ;; (temp (var-set temp-voting-power voting-power))
            ;; (volume-by-voting-power (map get-volume-by-voting-power volume))
            ;; FPTP and Block voting - Number of votes
            ;; (my-votes voting-power)

            ;; Quadratic or Weighted voting
            (volume-by-voting-power volume)
            ;; Quadratic or Weighted voting - Number of votes
            (my-votes (fold + volume u0))
        )
        ;; Validation
        (asserts! (and (> (len vote) u0) (is-eq (len vote) (len volume-by-voting-power)) (validate-vote-volume volume-by-voting-power)) ERR-NOT-VOTED)
        (asserts! (>= block-height (var-get start)) ERR-NOT-STARTED)
        (asserts! (<= block-height (var-get end)) ERR-ENDED)        
        (asserts! (not (have-i-voted)) ERR-ALREADY-VOTED)

        ;; FPTP and Block voting
        ;; (asserts! (> voting-power u0) ERR-FAILED-STRATEGY)

        ;; Quadratic voting
        ;; (asserts! (>= voting-power (fold + (map get-pow-value volume-by-voting-power) u0)) ERR-FAILED-STRATEGY)

        ;; Weigted voting
        (asserts! (>= voting-power (fold + volume-by-voting-power u0)) ERR-FAILED-STRATEGY)

        ;; Business logic
        ;; Process my vote
        (map process-my-vote vote volume-by-voting-power)

        ;; Register for reference
        (map-set users {id: tx-sender} {id: vote-id, vote: vote, volume: volume-by-voting-power, voting-power: voting-power})
        (map-set register {id: vote-id} {user: tx-sender, vote: vote, volume: volume-by-voting-power, voting-power: voting-power})

        ;; Increase the total votes
        (var-set total-votes (+ my-votes (var-get total-votes)))

        ;; Increase the total
        (var-set total vote-id)

        ;; Return
        (ok true)
    )
)

(define-read-only (get-results)
    (begin
        (ok {
                total: (var-get total), 
                total-votes: (var-get total-votes), 
                options: (var-get options), 
                results: (map get-single-result (var-get options))
            })
    )
)

(define-read-only (get-result-at-position (position uint))
    (ok (map-get? register {id: position}))
)
    
(define-read-only (get-result-by-user (user principal))
    (ok (map-get? users {id: user}))
)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Default assignments
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(var-set title u"BlockSurvey Poll")
(var-set description u"Description")
(var-set voting-system "First past the post")
(var-set options (list "option1" "option2"))
(var-set start u1)
(var-set end u1)
(map-set results {id: "option1"} {count: u0, name: u"Yes"})
(map-set results {id: "option2"} {count: u0, name: u"No"})