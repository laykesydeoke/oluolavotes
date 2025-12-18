;; Access Control - Role-Based Permissions (Clarity 4)
;; This contract manages roles and permissions for the governance system

;; Constants
(define-constant CONTRACT-OWNER tx-sender)

;; Role constants
(define-constant ROLE-ADMIN u1)
(define-constant ROLE-MODERATOR u2)
(define-constant ROLE-PROPOSER u3)
(define-constant ROLE-VOTER u4)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u501))
(define-constant ERR-INVALID-ROLE (err u502))
(define-constant ERR-ROLE-NOT-FOUND (err u503))
(define-constant ERR-USER-NOT-FOUND (err u504))
(define-constant ERR-ALREADY-HAS-ROLE (err u505))

;; Data maps

;; Track user roles with Clarity 4 timestamps
(define-map user-roles
    { user: principal, role: uint }
    {
        granted-at: uint,                    ;; Clarity 4: Unix timestamp
        granted-by: principal,
        active: bool
    }
)

;; Role metadata
(define-map roles
    { role-id: uint }
    {
        name: (string-ascii 50),
        description: (string-utf8 256),
        created-at: uint,                    ;; Clarity 4: Unix timestamp
        active: bool
    }
)

;; Track role counts per user
(define-map user-role-count
    { user: principal }
    uint
)

;; Initialize default roles
(map-set roles
    { role-id: ROLE-ADMIN }
    {
        name: "Admin",
        description: u"Full system access and permissions",
        created-at: stacks-block-time,
        active: true
    }
)

(map-set roles
    { role-id: ROLE-MODERATOR }
    {
        name: "Moderator",
        description: u"Can moderate proposals and users",
        created-at: stacks-block-time,
        active: true
    }
)

(map-set roles
    { role-id: ROLE-PROPOSER }
    {
        name: "Proposer",
        description: u"Can create new proposals",
        created-at: stacks-block-time,
        active: true
    }
)

(map-set roles
    { role-id: ROLE-VOTER }
    {
        name: "Voter",
        description: u"Can vote on proposals",
        created-at: stacks-block-time,
        active: true
    }
)

;; Grant admin role to contract owner
(map-set user-roles
    { user: CONTRACT-OWNER, role: ROLE-ADMIN }
    {
        granted-at: stacks-block-time,
        granted-by: CONTRACT-OWNER,
        active: true
    }
)

;; Read-only functions

;; Check if user has a specific role
(define-read-only (has-role (user principal) (role uint))
    (match (map-get? user-roles { user: user, role: role })
        role-data (ok (get active role-data))
        (ok false)
    )
)

;; Check if user is admin
(define-read-only (is-admin (user principal))
    (has-role user ROLE-ADMIN)
)

;; Check if user is moderator
(define-read-only (is-moderator (user principal))
    (has-role user ROLE-MODERATOR)
)

;; Check if user can create proposals
(define-read-only (can-create-proposal (user principal))
    (ok (or
        (unwrap-panic (has-role user ROLE-ADMIN))
        (unwrap-panic (has-role user ROLE-PROPOSER))
    ))
)

;; Check if user can vote
(define-read-only (can-vote (user principal))
    (ok (or
        (unwrap-panic (has-role user ROLE-ADMIN))
        (or
            (unwrap-panic (has-role user ROLE-VOTER))
            (unwrap-panic (has-role user ROLE-PROPOSER))
        )
    ))
)

;; Get role information
(define-read-only (get-role (role-id uint))
    (ok (map-get? roles { role-id: role-id }))
)

;; Get user role details
(define-read-only (get-user-role (user principal) (role uint))
    (ok (map-get? user-roles { user: user, role: role }))
)

;; Get user role count
(define-read-only (get-user-role-count (user principal))
    (ok (default-to u0 (map-get? user-role-count { user: user })))
)

;; Public functions

;; Grant role to user (only admins)
(define-public (grant-role (user principal) (role uint))
    (begin
        (asserts! (unwrap! (is-admin tx-sender) ERR-NOT-AUTHORIZED) ERR-NOT-AUTHORIZED)
        (asserts! (is-some (map-get? roles { role-id: role })) ERR-INVALID-ROLE)

        ;; Check if user already has role
        (match (map-get? user-roles { user: user, role: role })
            existing-role
                (if (get active existing-role)
                    ERR-ALREADY-HAS-ROLE
                    (begin
                        ;; Reactivate role
                        (map-set user-roles
                            { user: user, role: role }
                            {
                                granted-at: stacks-block-time,   ;; Clarity 4: Unix timestamp
                                granted-by: tx-sender,
                                active: true
                            }
                        )
                        (print {
                            event: "role-granted",
                            user: user,
                            role: role,
                            granted-by: tx-sender,
                            timestamp: stacks-block-time
                        })
                        (ok true)
                    )
                )
            ;; Grant new role
            (begin
                (map-set user-roles
                    { user: user, role: role }
                    {
                        granted-at: stacks-block-time,           ;; Clarity 4: Unix timestamp
                        granted-by: tx-sender,
                        active: true
                    }
                )
                (map-set user-role-count
                    { user: user }
                    (+ (default-to u0 (map-get? user-role-count { user: user })) u1)
                )
                (print {
                    event: "role-granted",
                    user: user,
                    role: role,
                    granted-by: tx-sender,
                    timestamp: stacks-block-time
                })
                (ok true)
            )
        )
    )
)

;; Revoke role from user (only admins)
(define-public (revoke-role (user principal) (role uint))
    (begin
        (asserts! (unwrap! (is-admin tx-sender) ERR-NOT-AUTHORIZED) ERR-NOT-AUTHORIZED)

        (match (map-get? user-roles { user: user, role: role })
            role-data
                (begin
                    (map-set user-roles
                        { user: user, role: role }
                        (merge role-data { active: false })
                    )
                    (print {
                        event: "role-revoked",
                        user: user,
                        role: role,
                        revoked-by: tx-sender,
                        timestamp: stacks-block-time
                    })
                    (ok true)
                )
            ERR-ROLE-NOT-FOUND
        )
    )
)

;; Batch grant roles (only admins)
(define-public (batch-grant-roles (users (list 50 principal)) (role uint))
    (begin
        (asserts! (unwrap! (is-admin tx-sender) ERR-NOT-AUTHORIZED) ERR-NOT-AUTHORIZED)
        (asserts! (is-some (map-get? roles { role-id: role })) ERR-INVALID-ROLE)

        (ok (map grant-role-helper users))
    )
)

;; Helper function for batch granting
(define-private (grant-role-helper (user principal))
    (begin
        (map-set user-roles
            { user: user, role: ROLE-VOTER }
            {
                granted-at: stacks-block-time,
                granted-by: tx-sender,
                active: true
            }
        )
        true
    )
)
