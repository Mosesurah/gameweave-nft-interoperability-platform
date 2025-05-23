;; gameweave-registry
;; A central registry for the GameWeave platform that enables NFT interoperability across games in the Stacks ecosystem.
;; This contract manages game registrations, NFT collections, and transformation rules that define how NFTs from one game
;; can be used or represented in another game.

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-GAME-ALREADY-REGISTERED (err u101))
(define-constant ERR-GAME-NOT-FOUND (err u102))
(define-constant ERR-COLLECTION-ALREADY-REGISTERED (err u103))
(define-constant ERR-COLLECTION-NOT-FOUND (err u104))
(define-constant ERR-RULE-ALREADY-EXISTS (err u105))
(define-constant ERR-RULE-NOT-FOUND (err u106))
(define-constant ERR-INVALID-PARAMETERS (err u107))
(define-constant ERR-SOURCE-COLLECTION-NOT-FOUND (err u108))
(define-constant ERR-TARGET-GAME-NOT-FOUND (err u109))

;; Data structures

;; Game information structure
;; Stores data about registered games including the owner, name, description, and a URI for metadata
(define-map games
  { game-id: uint }
  {
    owner: principal,
    name: (string-ascii 64),
    description: (string-utf8 256),
    metadata-uri: (optional (string-utf8 256))
  }
)

;; Track the total number of registered games
(define-data-var game-count uint u0)

;; NFT Collection information
;; Associates an NFT collection with a game and stores information about the collection
(define-map nft-collections
  { collection-id: uint }
  {
    game-id: uint,
    contract-address: principal,
    name: (string-ascii 64),
    description: (string-utf8 256),
    metadata-uri: (optional (string-utf8 256))
  }
)

;; Track the total number of registered NFT collections
(define-data-var collection-count uint u0)

;; Map game IDs to their associated collection IDs
(define-map game-collections
  { game-id: uint }
  { collection-ids: (list 20 uint) }
)

;; Transformation Rules - define how NFTs from one collection can be used in another game
(define-map transformation-rules
  { rule-id: uint }
  {
    source-collection-id: uint,
    target-game-id: uint,
    rule-type: (string-ascii 32),
    rule-data: (string-utf8 1024),  ;; JSON-formatted transformation rule data
    metadata-uri: (optional (string-utf8 256))
  }
)

;; Track the total number of transformation rules
(define-data-var rule-count uint u0)

;; Track rules by source collection and target game for easy lookup
(define-map collection-game-rules
  { source-collection-id: uint, target-game-id: uint }
  { rule-ids: (list 20 uint) }
)

;; Private functions

;; Helper function to check if a game exists
(define-private (is-game-registered (game-id uint))
  (is-some (map-get? games { game-id: game-id }))
)

;; Helper function to check if a collection exists
(define-private (is-collection-registered (collection-id uint))
  (is-some (map-get? nft-collections { collection-id: collection-id }))
)

;; Helper function to check if the sender is the game owner
(define-private (is-game-owner (game-id uint) (sender principal))
  (match (map-get? games { game-id: game-id })
    game-info (is-eq (get owner game-info) sender)
    false
  )
)




;; Public functions

;; Register a new game
;; Only the game owner can register a game
(define-public (register-game 
                (name (string-ascii 64)) 
                (description (string-utf8 256)) 
                (metadata-uri (optional (string-utf8 256))))
  (let
    (
      (new-game-id (+ (var-get game-count) u1))
    )
    ;; Increment the game counter and store the new game
    (var-set game-count new-game-id)
    (map-set games 
             { game-id: new-game-id }
             { 
               owner: tx-sender,
               name: name,
               description: description,
               metadata-uri: metadata-uri
             })
    (ok new-game-id)
  )
)

;; Update game information
;; Only the game owner can update game information
(define-public (update-game 
                (game-id uint) 
                (name (string-ascii 64)) 
                (description (string-utf8 256)) 
                (metadata-uri (optional (string-utf8 256))))
  (let
    (
      (game-info (map-get? games { game-id: game-id }))
    )
    (asserts! (is-some game-info) ERR-GAME-NOT-FOUND)
    (asserts! (is-eq (get owner (unwrap-panic game-info)) tx-sender) ERR-NOT-AUTHORIZED)
    
    (map-set games 
             { game-id: game-id }
             { 
               owner: tx-sender,
               name: name,
               description: description,
               metadata-uri: metadata-uri
             })
    (ok true)
  )
)



;; Update collection information
;; Only the game owner can update collection information
(define-public (update-collection 
                (collection-id uint) 
                (name (string-ascii 64)) 
                (description (string-utf8 256)) 
                (metadata-uri (optional (string-utf8 256))))
  (let
    (
      (collection-info (map-get? nft-collections { collection-id: collection-id }))
    )
    (asserts! (is-some collection-info) ERR-COLLECTION-NOT-FOUND)
    (let
      (
        (unwrapped-info (unwrap-panic collection-info))
        (game-id (get game-id unwrapped-info))
      )
      (asserts! (is-game-owner game-id tx-sender) ERR-NOT-AUTHORIZED)
      
      (map-set nft-collections 
               { collection-id: collection-id }
               { 
                 game-id: game-id,
                 contract-address: (get contract-address unwrapped-info),
                 name: name,
                 description: description,
                 metadata-uri: metadata-uri
               })
      (ok true)
    )
  )
)

;; Update a transformation rule
;; Only the target game owner can update a rule
(define-public (update-transformation-rule 
                (rule-id uint) 
                (rule-type (string-ascii 32)) 
                (rule-data (string-utf8 1024)) 
                (metadata-uri (optional (string-utf8 256))))
  (let
    (
      (rule-info (map-get? transformation-rules { rule-id: rule-id }))
    )
    (asserts! (is-some rule-info) ERR-RULE-NOT-FOUND)
    (let
      (
        (unwrapped-rule (unwrap-panic rule-info))
        (target-game-id (get target-game-id unwrapped-rule))
      )
      (asserts! (is-game-owner target-game-id tx-sender) ERR-NOT-AUTHORIZED)
      
      (map-set transformation-rules 
               { rule-id: rule-id }
               { 
                 source-collection-id: (get source-collection-id unwrapped-rule),
                 target-game-id: target-game-id,
                 rule-type: rule-type,
                 rule-data: rule-data,
                 metadata-uri: metadata-uri
               })
      (ok true)
    )
  )
)

;; Read-only functions

;; Get game information
(define-read-only (get-game (game-id uint))
  (map-get? games { game-id: game-id })
)

;; Get collection information
(define-read-only (get-collection (collection-id uint))
  (map-get? nft-collections { collection-id: collection-id })
)

;; Get transformation rule information
(define-read-only (get-transformation-rule (rule-id uint))
  (map-get? transformation-rules { rule-id: rule-id })
)

;; Get all collections for a game
(define-read-only (get-game-collections (game-id uint))
  (map-get? game-collections { game-id: game-id })
)

;; Get all transformation rules between a source collection and target game
(define-read-only (get-collection-game-rules (source-collection-id uint) (target-game-id uint))
  (map-get? collection-game-rules { source-collection-id: source-collection-id, target-game-id: target-game-id })
)

;; Check if an NFT from a collection is usable in a specific game
(define-read-only (is-nft-usable (collection-id uint) (token-id uint) (game-id uint))
  (match (map-get? collection-game-rules { source-collection-id: collection-id, target-game-id: game-id })
    rule-list (> (len (get rule-ids rule-list)) u0)  ;; If there are any rules defined, the NFT is usable
    false
  )
)

;; Get the total number of registered games
(define-read-only (get-game-count)
  (var-get game-count)
)

;; Get the total number of registered collections
(define-read-only (get-collection-count)
  (var-get collection-count)
)

;; Get the total number of transformation rules
(define-read-only (get-rule-count)
  (var-get rule-count)
)