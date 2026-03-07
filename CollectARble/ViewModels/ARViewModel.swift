import SwiftUI
import RealityKit
import ARKit
import Combine

@Observable
class ARViewModel {
    var currentCreature: Creature?
    var isCreatureSpawned: Bool = false
    var isAttacking: Bool = false
    var statusMessage: String = "Point your camera at a CollectARble card"
    var selectedCreatureIndex: Int = 0
    var detectedCardName: String?
    var isPokeballAnimating: Bool = false
    var isCardDetected: Bool = false
    var cardDetectionProgress: Float = 0
    var showAttackFlash: Bool = false
    var creatureHP: Int = 120
    var creatureMaxHP: Int = 120
    var lastDamage: Int = 0
    var showDamageNumber: Bool = false
    var isTrackingCard: Bool = false

    // Throw mode
    var isThrowMode: Bool = false
    var throwablePokeball: Entity?
    var isReadyToThrow: Bool = false
    private var throwModeTimer: Timer?

    // Card drop mode (summoning from collection)
    var isCardDropMode: Bool = false
    var isCardOnSurface: Bool = false
    var waitingForSurface: Bool = false
    private var droppedCardEntity: Entity?
    private var droppedCardAnchor: AnchorEntity?

    // Chat
    var showChat: Bool = false
    var lastCharacterMessage: String = ""
    var showSpeechBubble: Bool = false

    private var creatureEntity: Entity?
    private var pokeballEntity: Entity?
    private var particleEntities: [Entity] = []
    private var arView: ARView?
    private var idleTimer: Timer?
    private var creatureAnchor: AnchorEntity?
    private var currentCreatureScale: Float = 0.003
    private var idlePhase: Float = 0
    private var trackedImageAnchorID: UUID?
    private var isTrackingWithCard: Bool = false  // True when spawned from card detection

    var availableCreatures: [Creature] {
        Creature.allCreatures
    }

    func setARView(_ view: ARView) {
        arView = view
    }

    // MARK: - Session Configuration

    func configureSession() {
        guard let arView else { return }

        // Generate reference images from our card designs
        let referenceImages = CardReferenceService.generateReferenceImages()

        // Use world tracking with BOTH plane detection AND image detection
        // This allows tap-to-place AND card scanning to work together
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        config.environmentTexturing = .automatic

        if !referenceImages.isEmpty {
            config.detectionImages = referenceImages
            config.maximumNumberOfTrackedImages = 1
            statusMessage = "Point at a card, or tap a flat surface"
        } else {
            statusMessage = "Point at a flat surface and tap to place creature"
        }

        arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
    }

    // MARK: - Image Anchor Handling (primary path — creature tracks with card)

    func handleImageAnchorAdded(_ imageAnchor: ARImageAnchor) {
        guard !isCreatureSpawned, !isPokeballAnimating else { return }

        // Identify which creature matches the detected card
        if let imageName = imageAnchor.referenceImage.name,
           let index = availableCreatures.firstIndex(where: { $0.id == imageName }) {
            selectedCreatureIndex = index
        }

        trackedImageAnchorID = imageAnchor.identifier
        isCardDetected = true
        cardDetectionProgress = 1.0
        isTrackingWithCard = true  // Mark that we're tracking with a card
        statusMessage = "Card detected! Summoning creature..."

        beginSpawnOnCard(imageAnchor: imageAnchor)
    }

    func handleImageAnchorUpdated(_ imageAnchor: ARImageAnchor) {
        // Update tracking state
        if imageAnchor.identifier == trackedImageAnchorID {
            isTrackingCard = imageAnchor.isTracked

            // Update creature position to follow the card
            if isTrackingWithCard && isCreatureSpawned, let anchor = creatureAnchor {
                // Smoothly update anchor to follow card position
                let newTransform = Transform(matrix: imageAnchor.transform)
                anchor.transform = newTransform
            }

            if !imageAnchor.isTracked && isCreatureSpawned {
                statusMessage = "Move camera back to the card"
            } else if imageAnchor.isTracked && isCreatureSpawned {
                if let creature = currentCreature {
                    statusMessage = "\(creature.name) — HP: \(creatureHP)/\(creatureMaxHP)"
                }
            }
        }
    }

    // MARK: - Frame Processing (fallback rectangle detection)

    func processFrame(_ frame: ARFrame) {
        // Only use frame-based detection if image tracking didn't fire
        // (this is a no-op when using ARImageTrackingConfiguration since
        // image anchors handle everything)
    }

    // MARK: - Spawning (Card-Tracked)

    private func beginSpawnOnCard(imageAnchor: ARImageAnchor) {
        guard let arView else { return }

        let creature = availableCreatures[selectedCreatureIndex]
        currentCreature = creature
        detectedCardName = creature.id
        isPokeballAnimating = true
        isCardDetected = false
        cardDetectionProgress = 0

        // Set HP based on creature element
        switch creature.element {
        case .fire: creatureMaxHP = 120; creatureHP = 120
        case .ice: creatureMaxHP = 100; creatureHP = 100
        case .nature: creatureMaxHP = 90; creatureHP = 90
        case .sports: creatureMaxHP = 110; creatureHP = 110
        }

        // Create anchor that will track with the card
        // We use a world anchor but update its transform in handleImageAnchorUpdated
        let anchor = AnchorEntity(world: imageAnchor.transform)
        arView.scene.addAnchor(anchor)
        creatureAnchor = anchor

        let ballType = SpawnBallService.ballType(for: creature)
        let ballName = ballType == .football ? "Football" : "Pokéball"
        statusMessage = "Summoning \(creature.name)!"

        Task {
            if let ball = await SpawnBallService.loadBall(for: creature) {
                pokeballEntity = ball
                ball.position = SIMD3<Float>(0, 0.05, 0)  // Start above the card
                anchor.addChild(ball)
                statusMessage = "\(ballName) incoming!"

                await SpawnBallService.runSpawnSequence(
                    ball: ball,
                    anchor: anchor,
                    creature: creature,
                    onBallLanded: {
                        self.statusMessage = "\(ballName) is opening..."
                    },
                    onCreatureReady: { entity in
                        self.creatureEntity = entity
                        self.isCreatureSpawned = true
                        self.isPokeballAnimating = false
                        self.statusMessage = "\(creature.name) appeared! HP: \(self.creatureHP)/\(self.creatureMaxHP)"
                        self.startIdleLoop()
                    }
                )
            } else {
                await spawnWithoutPokeball(creature: creature, anchor: anchor)
            }
        }
    }

    // MARK: - Spawning (World-Fixed)

    func spawnCreature(at worldTransform: simd_float4x4) {
        guard !isCreatureSpawned, !isPokeballAnimating else { return }
        beginSpawn(at: worldTransform)
    }

    private func beginSpawn(at worldTransform: simd_float4x4) {
        guard let arView else { return }

        let creature = availableCreatures[selectedCreatureIndex]
        currentCreature = creature
        detectedCardName = creature.id
        isPokeballAnimating = true
        isCardDetected = false
        cardDetectionProgress = 0

        // Set HP based on creature element
        switch creature.element {
        case .fire: creatureMaxHP = 120; creatureHP = 120
        case .ice: creatureMaxHP = 100; creatureHP = 100
        case .nature: creatureMaxHP = 90; creatureHP = 90
        case .sports: creatureMaxHP = 110; creatureHP = 110
        }

        let anchor = AnchorEntity(world: worldTransform)
        arView.scene.addAnchor(anchor)
        creatureAnchor = anchor

        let ballType = SpawnBallService.ballType(for: creature)
        let ballName = ballType == .football ? "Football" : "Pokéball"
        statusMessage = "Summoning \(creature.name)!"

        Task {
            if let ball = await SpawnBallService.loadBall(for: creature) {
                pokeballEntity = ball
                ball.position = SIMD3<Float>(0, 0.05, 0)  // Start above surface for drop animation
                anchor.addChild(ball)
                statusMessage = "\(ballName) incoming!"

                await SpawnBallService.runSpawnSequence(
                    ball: ball,
                    anchor: anchor,
                    creature: creature,
                    onBallLanded: {
                        self.statusMessage = "\(ballName) is opening..."
                    },
                    onCreatureReady: { entity in
                        self.creatureEntity = entity
                        self.isCreatureSpawned = true
                        self.isPokeballAnimating = false
                        self.statusMessage = "\(creature.name) appeared! HP: \(self.creatureHP)/\(self.creatureMaxHP)"
                        self.startIdleLoop()
                    }
                )
            } else {
                await spawnWithoutPokeball(creature: creature, anchor: anchor)
            }
        }
    }

    private func spawnWithoutPokeball(creature: Creature, anchor: AnchorEntity) async {
        if creature.bundledModelName != nil {
            statusMessage = "Loading \(creature.name)..."
            let entity = await loadBundledModel(for: creature)
            entity.scale = SIMD3<Float>(repeating: 0.0001)
            entity.position = SIMD3<Float>(0, 0, 0)  // Start at anchor level
            anchor.addChild(entity)

            let targetScale: Float = creature.modelScale
            print("DEBUG: Spawning creature with scale \(targetScale)")
            var target = entity.transform
            target.scale = SIMD3<Float>(repeating: targetScale)
            target.translation = SIMD3<Float>(0, 0, 0)  // On the surface
            entity.move(to: target, relativeTo: anchor, duration: 0.6, timingFunction: .easeOut)
            currentCreatureScale = targetScale

            for animation in entity.availableAnimations {
                entity.playAnimation(animation.repeat())
            }

            creatureEntity = entity
            isCreatureSpawned = true
            isPokeballAnimating = false
            statusMessage = "\(creature.name) appeared! HP: \(creatureHP)/\(creatureMaxHP)"
            startIdleLoop()
        } else {
            let entity = CreatureBuilder.buildCreature(for: creature)
            entity.position.y = 0.005
            anchor.addChild(entity)
            creatureEntity = entity
            isCreatureSpawned = true
            isPokeballAnimating = false
            statusMessage = "\(creature.name) appeared!"
            CreatureBuilder.animateSpawn(entity: entity)
            startIdleLoop()
        }
    }

    // MARK: - Gestures

    func handlePanGesture(translation: CGPoint) {
        guard let entity = creatureEntity else { return }

        // Ignore very small movements (deadzone)
        guard abs(translation.x) > 2 else { return }

        // Only use horizontal (X) component for rotation - ignore vertical completely
        let rotationSpeed: Float = 0.008
        let yaw = Float(translation.x) * rotationSpeed

        // Preserve current position and scale before rotation
        let currentPosition = entity.position
        let currentScale = entity.scale

        // Apply only Y-axis rotation
        let currentRotation = entity.transform.rotation
        let deltaRotation = simd_quatf(angle: yaw, axis: SIMD3<Float>(0, 1, 0))
        entity.transform.rotation = deltaRotation * currentRotation

        // Explicitly restore position and scale to prevent any drift
        entity.position = currentPosition
        entity.scale = currentScale
    }

    func handlePinchGesture(scale: Float) {
        guard let entity = creatureEntity else { return }
        let newScale = currentCreatureScale * scale
        // Cap max scale to keep creature within card bounds (~65mm card)
        let clampedScale = min(max(newScale, 0.001), 0.01)
        print("DEBUG: Pinch scale changed to \(clampedScale)")
        entity.scale = SIMD3<Float>(repeating: clampedScale)
    }

    func handlePinchEnd(scale: Float) {
        let newScale = currentCreatureScale * scale
        currentCreatureScale = min(max(newScale, 0.001), 0.01)
        print("DEBUG: Pinch ended, new scale = \(currentCreatureScale)")
    }

    // MARK: - Attack

    func triggerAttack() {
        guard let creature = currentCreature,
              let entity = creatureEntity,
              !isAttacking else { return }

        isAttacking = true
        statusMessage = "\(creature.attackName)!"

        // Calculate damage
        let baseDamage = Int.random(in: 20...40)
        lastDamage = baseDamage
        creatureHP = max(0, creatureHP - baseDamage)

        // Show screen flash
        showAttackFlash = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.15))
            showAttackFlash = false
        }

        // Show damage number
        showDamageNumber = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.0))
            showDamageNumber = false
        }

        // Attack animation: quick lunge forward then back
        let originalTransform = entity.transform
        var lungeTransform = originalTransform
        lungeTransform.translation.z += 0.02
        lungeTransform.scale = originalTransform.scale * 1.15
        entity.move(to: lungeTransform, relativeTo: entity.parent, duration: 0.12, timingFunction: .easeIn)

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.15))
            entity.move(to: originalTransform, relativeTo: entity.parent, duration: 0.2, timingFunction: .easeOut)
        }

        let position = entity.position(relativeTo: nil)
        let particles = ParticleEffectBuilder.createAttackParticles(for: creature, at: position)

        if let anchor = entity.parent {
            for particle in particles {
                anchor.addChild(particle)
            }
        }

        particleEntities = particles

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            ParticleEffectBuilder.removeParticles(particles, from: entity)
            isAttacking = false

            if creatureHP <= 0 {
                statusMessage = "\(creature.name) fainted!"
                await returnCreatureToBall()
            } else {
                statusMessage = "\(creature.name) — HP: \(creatureHP)/\(creatureMaxHP)"
            }
        }
    }

    // MARK: - Return to Ball Animation

    private func returnCreatureToBall() async {
        guard let arView,
              let creature = currentCreature,
              let creatureEntity = creatureEntity,
              let anchor = creatureAnchor else { return }

        // Stop idle animation
        idleTimer?.invalidate()
        idleTimer = nil

        // Load a pokeball for the capture animation
        let ballType = SpawnBallService.ballType(for: creature)
        guard let ball = await SpawnBallService.loadBall(type: ballType) else {
            resetScene()
            return
        }

        // Position ball above creature
        ball.position = creatureEntity.position + SIMD3<Float>(0, 0.15, 0)
        ball.scale = SIMD3<Float>(repeating: ballType.landedScale * 0.5)
        anchor.addChild(ball)

        statusMessage = "\(creature.name) is returning..."

        // Ball drops down toward creature
        var ballDrop = ball.transform
        ballDrop.translation = creatureEntity.position + SIMD3<Float>(0, 0.02, 0)
        ballDrop.scale = SIMD3<Float>(repeating: ballType.landedScale)
        ball.move(to: ballDrop, relativeTo: anchor, duration: 0.3, timingFunction: .easeIn)
        try? await Task.sleep(for: .seconds(0.3))

        // Red beam effect - creature shrinks and gets sucked into ball
        statusMessage = "Return!"

        // Create red glow around creature - non-metallic for soft glow
        var glowMaterial = SimpleMaterial()
        glowMaterial.color = .init(tint: .red.withAlphaComponent(0.6))
        glowMaterial.metallic = .init(floatLiteral: 0.0)
        glowMaterial.roughness = .init(floatLiteral: 0.8)
        let glowSphere = ModelEntity(mesh: .generateSphere(radius: 0.03), materials: [glowMaterial])
        glowSphere.position = creatureEntity.position
        anchor.addChild(glowSphere)

        // Expand glow
        var glowExpand = glowSphere.transform
        glowExpand.scale = SIMD3<Float>(repeating: 3.0)
        glowSphere.move(to: glowExpand, relativeTo: anchor, duration: 0.2, timingFunction: .easeOut)
        try? await Task.sleep(for: .seconds(0.2))

        // Shrink creature rapidly while turning red-ish
        var creatureShrink = creatureEntity.transform
        creatureShrink.scale = SIMD3<Float>(repeating: 0.0001)
        creatureShrink.translation = ball.position
        creatureEntity.move(to: creatureShrink, relativeTo: anchor, duration: 0.4, timingFunction: .easeIn)

        // Shrink glow toward ball
        var glowShrink = glowSphere.transform
        glowShrink.scale = SIMD3<Float>(repeating: 0.01)
        glowShrink.translation = ball.position
        glowSphere.move(to: glowShrink, relativeTo: anchor, duration: 0.4, timingFunction: .easeIn)

        try? await Task.sleep(for: .seconds(0.4))

        // Remove creature and glow
        creatureEntity.removeFromParent()
        glowSphere.removeFromParent()

        // Ball shakes (captured!)
        for i in 0..<3 {
            let angle: Float = (i % 2 == 0) ? 0.2 : -0.2
            var shake = ball.transform
            shake.rotation = simd_quatf(angle: angle, axis: SIMD3<Float>(0, 0, 1))
            ball.move(to: shake, relativeTo: anchor, duration: 0.15, timingFunction: .easeInOut)
            try? await Task.sleep(for: .seconds(0.15))
        }

        // Ball settles
        var settle = ball.transform
        settle.rotation = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
        ball.move(to: settle, relativeTo: anchor, duration: 0.1, timingFunction: .easeOut)
        try? await Task.sleep(for: .seconds(0.3))

        // Flash indicating successful capture - non-metallic for soft glow
        var flashMaterial = SimpleMaterial()
        flashMaterial.color = .init(tint: .white.withAlphaComponent(0.9))
        flashMaterial.metallic = .init(floatLiteral: 0.0)
        flashMaterial.roughness = .init(floatLiteral: 0.6)
        let flash = ModelEntity(mesh: .generateSphere(radius: 0.01), materials: [flashMaterial])
        flash.position = ball.position
        anchor.addChild(flash)

        var flashExpand = flash.transform
        flashExpand.scale = SIMD3<Float>(repeating: 8.0)
        flash.move(to: flashExpand, relativeTo: anchor, duration: 0.2, timingFunction: .easeOut)
        try? await Task.sleep(for: .seconds(0.2))

        flash.removeFromParent()

        // Ball shrinks and disappears
        var ballShrink = ball.transform
        ballShrink.scale = SIMD3<Float>(repeating: 0.0001)
        ball.move(to: ballShrink, relativeTo: anchor, duration: 0.3, timingFunction: .easeIn)
        try? await Task.sleep(for: .seconds(0.3))

        ball.removeFromParent()

        statusMessage = "\(creature.name) returned to ball! Tap to summon again"

        // Reset state
        self.creatureEntity = nil
        isCreatureSpawned = false
        isTrackingWithCard = false
        isAttacking = false
        creatureHP = creatureMaxHP
    }

    // MARK: - Card Drop Mode (Summon from Collection)

    func enterCardDropMode() {
        guard let arView, !isCreatureSpawned, !isPokeballAnimating else {
            print("DEBUG: enterCardDropMode failed - arView:\(arView != nil) spawned:\(isCreatureSpawned) animating:\(isPokeballAnimating)")
            return
        }

        isCardDropMode = true
        waitingForSurface = true
        isCardOnSurface = false
        statusMessage = "Tap a surface to place your card..."
        print("DEBUG: Entered card drop mode successfully")
    }

    /// Try to enter card drop mode, returns true if successful
    func enterCardDropModeIfReady() -> Bool {
        guard arView != nil, !isCreatureSpawned, !isPokeballAnimating else {
            return false
        }

        isCardDropMode = true
        waitingForSurface = true
        isCardOnSurface = false
        statusMessage = "Tap a surface to place your card..."
        print("DEBUG: Entered card drop mode successfully")
        return true
    }

    func dropCardOnSurface(at worldTransform: simd_float4x4) {
        guard let arView, isCardDropMode, waitingForSurface else { return }

        waitingForSurface = false
        let creature = availableCreatures[selectedCreatureIndex]
        statusMessage = "Dropping \(creature.name) card..."

        // Create anchor for the card
        let anchor = AnchorEntity(world: worldTransform)
        arView.scene.addAnchor(anchor)
        droppedCardAnchor = anchor

        Task {
            // Create a 3D card entity
            let cardEntity = await createDroppedCard(for: creature)
            droppedCardEntity = cardEntity
            print("DEBUG: Created dropped card entity for \(creature.name)")

            // Start card high above the surface, small scale
            cardEntity.position = SIMD3<Float>(0, 0.5, 0)
            cardEntity.scale = SIMD3<Float>(repeating: 0.01)  // Start small

            // Initial rotation - card horizontal but tilted back (front facing slightly toward camera)
            cardEntity.orientation = simd_quatf(angle: .pi * 0.1, axis: SIMD3<Float>(1, 0, 0))

            anchor.addChild(cardEntity)
            print("DEBUG: Card added to anchor at position \(cardEntity.position)")

            // Animate card growing to full size (1.0 = real world size since mesh is in meters)
            var growTransform = cardEntity.transform
            growTransform.scale = SIMD3<Float>(repeating: 1.0)  // Full size (63mm x 88mm)
            cardEntity.move(to: growTransform, relativeTo: anchor, duration: 0.3, timingFunction: .easeOut)
            try? await Task.sleep(for: .seconds(0.3))
            print("DEBUG: Card scaled to full size")

            // Card tumbles and falls to the surface
            statusMessage = "\(creature.name) card incoming!"

            // Fall with slight tumble rotation
            let fallDuration: Double = 0.5
            var fallTransform = cardEntity.transform
            fallTransform.translation = SIMD3<Float>(0, 0.005, 0)  // Land just above surface
            fallTransform.rotation = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))  // Flat
            cardEntity.move(to: fallTransform, relativeTo: anchor, duration: fallDuration, timingFunction: .easeIn)

            try? await Task.sleep(for: .seconds(fallDuration))
            print("DEBUG: Card landed on surface")

            // Card bounces slightly
            var bounceUp = cardEntity.transform
            bounceUp.translation.y = 0.02
            cardEntity.move(to: bounceUp, relativeTo: anchor, duration: 0.08, timingFunction: .easeOut)
            try? await Task.sleep(for: .seconds(0.08))

            var bounceDown = cardEntity.transform
            bounceDown.translation.y = 0.003  // Settle on surface
            cardEntity.move(to: bounceDown, relativeTo: anchor, duration: 0.1, timingFunction: .easeIn)
            try? await Task.sleep(for: .seconds(0.1))

            // Card is now on the surface
            isCardOnSurface = true

            // Add a subtle glow/pulse to the card
            await addCardGlow(to: cardEntity, anchor: anchor, creature: creature)

            statusMessage = "Card ready! Now throw to summon \(creature.name)!"

            // Automatically enter throw mode after a brief pause
            try? await Task.sleep(for: .seconds(0.5))
            await MainActor.run {
                self.enterThrowModeFromCard()
            }
        }
    }

    private func createDroppedCard(for creature: Creature) async -> Entity {
        print("DEBUG: Creating dropped card for \(creature.name)")
        return await create2DCard(for: creature)
    }

    /// Create 2D card with texture
    private func create2DCard(for creature: Creature) async -> Entity {
        // Standard trading card: 63mm x 88mm
        let cardWidth: Float = 0.063
        let cardHeight: Float = 0.088

        let cardEntity = Entity()
        cardEntity.name = "droppedCard"

        // Create the front face as a plane
        let frontPlaneMesh = MeshResource.generatePlane(width: cardWidth, depth: cardHeight)

        // Load the card image - same images used in CardCollectionView
        var frontMaterial: RealityKit.Material = SimpleMaterial(color: creature.element.primaryColor, isMetallic: false)

        let cardImageName: String
        switch creature.id {
        case "messi":
            cardImageName = "messi_card_front"
        case "charizard":
            cardImageName = "charizard_holographic"
        default:
            cardImageName = ""
        }

        if let cardImage = loadCardImage(named: cardImageName) {
            print("DEBUG: Card image loaded: \(cardImageName), size: \(cardImage.size)")

            // Crop image to match card aspect ratio (63:88 = 0.716)
            let targetAspect = CGFloat(cardWidth) / CGFloat(cardHeight)
            let croppedImage = cropImageToAspectRatio(cardImage, targetAspect: targetAspect)

            if let cgImage = croppedImage.cgImage {
                do {
                    let texture = try await TextureResource(image: cgImage, options: .init(semantic: .color))
                    var unlitMaterial = UnlitMaterial()
                    unlitMaterial.color = .init(tint: .white, texture: .init(texture))
                    frontMaterial = unlitMaterial
                    print("DEBUG: Card texture applied successfully, cropped to \(croppedImage.size)")
                } catch {
                    print("DEBUG: Failed to generate texture: \(error)")
                }
            }
        }

        // Front face plane
        let frontPlane = ModelEntity(mesh: frontPlaneMesh, materials: [frontMaterial])
        frontPlane.position = SIMD3<Float>(0, 0.0005, 0)
        cardEntity.addChild(frontPlane)

        // Back face plane
        let backMaterial = SimpleMaterial(color: UIColor(red: 0.15, green: 0.1, blue: 0.25, alpha: 1.0), isMetallic: false)
        let backPlane = ModelEntity(mesh: frontPlaneMesh, materials: [backMaterial])
        backPlane.position = SIMD3<Float>(0, -0.0005, 0)
        backPlane.orientation = simd_quatf(angle: .pi, axis: SIMD3<Float>(1, 0, 0))
        cardEntity.addChild(backPlane)

        // Add thin edges
        let edgeMaterial = SimpleMaterial(color: .white, isMetallic: false)
        let edgeThickness: Float = 0.001
        let longEdgeMesh = MeshResource.generateBox(width: cardWidth, height: edgeThickness, depth: 0.001)
        let shortEdgeMesh = MeshResource.generateBox(width: 0.001, height: edgeThickness, depth: cardHeight)

        let frontEdge = ModelEntity(mesh: longEdgeMesh, materials: [edgeMaterial])
        frontEdge.position = SIMD3<Float>(0, 0, cardHeight / 2)
        cardEntity.addChild(frontEdge)

        let backEdge = ModelEntity(mesh: longEdgeMesh, materials: [edgeMaterial])
        backEdge.position = SIMD3<Float>(0, 0, -cardHeight / 2)
        cardEntity.addChild(backEdge)

        let leftEdge = ModelEntity(mesh: shortEdgeMesh, materials: [edgeMaterial])
        leftEdge.position = SIMD3<Float>(-cardWidth / 2, 0, 0)
        cardEntity.addChild(leftEdge)

        let rightEdge = ModelEntity(mesh: shortEdgeMesh, materials: [edgeMaterial])
        rightEdge.position = SIMD3<Float>(cardWidth / 2, 0, 0)
        cardEntity.addChild(rightEdge)

        print("DEBUG: 2D card entity created")
        return cardEntity
    }

    private func addCardGlow(to card: Entity, anchor: AnchorEntity, creature: Creature) async {
        // Add pulsing glow effect around the card
        let glowMesh = MeshResource.generateBox(width: 0.07, height: 0.002, depth: 0.095, cornerRadius: 0.005)
        var glowMaterial = SimpleMaterial()
        glowMaterial.color = .init(tint: creature.element.primaryColor.withAlphaComponent(0.6))
        glowMaterial.metallic = .init(floatLiteral: 0.0)  // Non-metallic for soft glow
        glowMaterial.roughness = .init(floatLiteral: 0.7)

        let glowEntity = ModelEntity(mesh: glowMesh, materials: [glowMaterial])
        glowEntity.position = SIMD3<Float>(0, -0.001, 0)
        card.addChild(glowEntity)

        // Pulse animation
        Task {
            while isCardOnSurface && !isCreatureSpawned {
                var expandTransform = glowEntity.transform
                expandTransform.scale = SIMD3<Float>(1.1, 1.0, 1.1)
                glowEntity.move(to: expandTransform, relativeTo: card, duration: 0.8, timingFunction: .easeInOut)
                try? await Task.sleep(for: .seconds(0.8))

                var shrinkTransform = glowEntity.transform
                shrinkTransform.scale = SIMD3<Float>(1.0, 1.0, 1.0)
                glowEntity.move(to: shrinkTransform, relativeTo: card, duration: 0.8, timingFunction: .easeInOut)
                try? await Task.sleep(for: .seconds(0.8))
            }
        }
    }

    private func enterThrowModeFromCard() {
        guard let arView, isCardOnSurface, !isCreatureSpawned else { return }

        // Ensure we have a card anchor, otherwise fall back to normal throw mode
        guard droppedCardAnchor != nil else {
            enterThrowMode()
            return
        }

        isThrowMode = true
        isReadyToThrow = false
        let creature = availableCreatures[selectedCreatureIndex]
        let ballType = SpawnBallService.ballType(for: creature)
        let ballName = ballType == .football ? "Football" : "Pokeball"
        statusMessage = "Throw the \(ballName) at the card!"

        // Create throwable ball
        Task {
            let cameraTransform = arView.cameraTransform.matrix

            if let pokeball = await PokeballThrowService.createThrowableBall(for: creature, at: cameraTransform) {
                throwablePokeball = pokeball

                // Add to a new anchor in front of camera
                let throwAnchor = AnchorEntity(world: cameraTransform)
                arView.scene.addAnchor(throwAnchor)
                creatureAnchor = throwAnchor
                throwAnchor.addChild(pokeball)

                // Use default throwScale (already set by createThrowableBall)

                isReadyToThrow = true
                statusMessage = "Swipe to throw the \(ballName) at your card!"

                startThrowModeTracking()
            }
        }
    }

    // MARK: - Throw Mode

    func enterThrowMode() {
        guard let arView, !isCreatureSpawned, !isPokeballAnimating else { return }

        // Prevent entering throw mode twice
        if isThrowMode {
            print("DEBUG: Already in throw mode, ignoring")
            return
        }

        // Clean up any existing throwable ball
        if let existingBall = throwablePokeball {
            existingBall.removeFromParent()
            throwablePokeball = nil
        }
        if let existingAnchor = creatureAnchor {
            arView.scene.removeAnchor(existingAnchor)
            creatureAnchor = nil
        }

        isThrowMode = true
        isReadyToThrow = false
        let creature = availableCreatures[selectedCreatureIndex]
        let ballType = SpawnBallService.ballType(for: creature)
        let ballName = ballType == .football ? "Football" : "Pokeball"
        statusMessage = "Finding floor surface..."

        Task {
            // Use cameraTransform directly to avoid retaining ARFrames
            let cameraTransform = arView.cameraTransform.matrix

            // First, verify we can find a floor
            let floorY = PokeballThrowService.findFloorLevel(arView: arView, cameraTransform: cameraTransform)
            let cameraY = cameraTransform.columns.3.y
            let floorDistance = cameraY - floorY

            if floorDistance > 0.3 && floorDistance < 3.0 {
                statusMessage = "Swipe forward to throw the \(ballName)!"
            } else {
                statusMessage = "Point at floor, then swipe to throw!"
            }
            print("DEBUG: Floor detected at \(floorY), camera at \(cameraY), distance: \(floorDistance)m")

            if let ball = await PokeballThrowService.createThrowableBall(for: creature, at: cameraTransform) {
                // Add ball directly to scene root for world-space positioning during throw
                let anchor = AnchorEntity(world: .zero)
                arView.scene.addAnchor(anchor)
                anchor.addChild(ball)
                throwablePokeball = ball
                creatureAnchor = anchor
                isReadyToThrow = true
                print("DEBUG: Throw mode ready, \(ballName) at \(ball.position) scale \(ball.scale)")

                // Start timer to keep ball in front of camera
                await MainActor.run {
                    self.startThrowModeTracking()
                }
            }
        }
    }

    private func startThrowModeTracking() {
        throwModeTimer?.invalidate()
        throwModeTimer = Timer.scheduledTimer(withTimeInterval: 1.0/30.0, repeats: true) { [weak self] _ in
            guard let self,
                  self.isThrowMode,
                  self.isReadyToThrow,
                  let pokeball = self.throwablePokeball,
                  let arView = self.arView else {
                return
            }
            // Use cameraTransform directly instead of currentFrame to avoid retaining ARFrames
            let cameraTransform = arView.cameraTransform.matrix
            PokeballThrowService.updatePokeballPosition(pokeball: pokeball, cameraTransform: cameraTransform)
        }
    }

    func exitThrowMode() {
        throwModeTimer?.invalidate()
        throwModeTimer = nil
        isThrowMode = false
        isReadyToThrow = false
        throwablePokeball?.removeFromParent()
        throwablePokeball = nil
        // Remove the throw anchor if it exists
        if let anchor = creatureAnchor, !isCreatureSpawned {
            arView?.scene.removeAnchor(anchor)
            creatureAnchor = nil
        }
        statusMessage = "Point your camera at a CollectARble card"
    }

    func exitCardDropMode() {
        isCardDropMode = false
        isCardOnSurface = false
        waitingForSurface = false

        // Clean up dropped card entity
        droppedCardEntity?.removeFromParent()
        droppedCardEntity = nil

        if let anchor = droppedCardAnchor {
            arView?.scene.removeAnchor(anchor)
            droppedCardAnchor = nil
        }

        // Also exit throw mode if we were in it
        exitThrowMode()
        statusMessage = "Point your camera at a CollectARble card"
    }

    func handleThrowGesture(velocity: CGPoint) {
        print("DEBUG: handleThrowGesture called with velocity \(velocity)")
        guard isThrowMode, isReadyToThrow,
              let arView,
              let ball = throwablePokeball else {
            print("DEBUG: Throw guard failed - isThrowMode:\(isThrowMode) isReadyToThrow:\(isReadyToThrow)")
            return
        }

        // Use cameraTransform directly to avoid retaining ARFrames
        let cameraTransform = arView.cameraTransform.matrix

        // Calculate throw strength
        let throwSpeed = sqrt(velocity.x * velocity.x + velocity.y * velocity.y)
        print("DEBUG: Throw speed: \(throwSpeed)")

        // Minimum velocity threshold (ignore weak gestures)
        guard throwSpeed > 100 else {
            print("DEBUG: Throw too weak, ignoring")
            return
        }

        // Stop tracking timer
        throwModeTimer?.invalidate()
        throwModeTimer = nil
        isReadyToThrow = false

        let creature = availableCreatures[selectedCreatureIndex]
        let ballType = SpawnBallService.ballType(for: creature)
        let ballName = ballType == .football ? "Football" : "Pokeball"
        statusMessage = "\(ballName) thrown!"

        // If in card drop mode, animate ball to land on the card
        if isCardDropMode, let cardAnchor = droppedCardAnchor {
            let cardPosition = cardAnchor.position(relativeTo: nil)
            print("DEBUG: Card drop mode - targeting card at \(cardPosition)")

            animateThrowToCard(ball: ball, targetPosition: cardPosition, arView: arView)
            return
        }

        // Normal throw mode - use physics trajectory
        let floorY = PokeballThrowService.findFloorLevel(arView: arView, cameraTransform: cameraTransform)
        print("DEBUG: Detected floor at y=\(floorY), camera at y=\(cameraTransform.columns.3.y)")

        let startPos = ball.position(relativeTo: nil)
        print("DEBUG: Throwing from position \(startPos)")

        // Calculate trajectory
        let trajectory = PokeballThrowService.calculateThrowTrajectory(
            startPosition: startPos,
            velocity: SIMD2<Float>(Float(velocity.x), Float(-velocity.y)),
            cameraTransform: cameraTransform,
            targetY: floorY
        )

        // Animate the throw with real-time floor tracking
        PokeballThrowService.animateThrow(
            ball: ball,
            trajectory: trajectory,
            arView: arView
        ) { [weak self] landPosition in
            print("DEBUG: Ball landed at \(landPosition)")
            guard let self else { return }
            DispatchQueue.main.async {
                self.handlePokeballLanded(at: landPosition)
            }
        }
    }

    /// Animate the ball to land on the dropped card's position
    private func animateThrowToCard(ball: Entity, targetPosition: SIMD3<Float>, arView: ARView) {
        let startPos = ball.position(relativeTo: nil)
        let creature = availableCreatures[selectedCreatureIndex]
        let ballType = SpawnBallService.ballType(for: creature)
        let ballName = ballType == .football ? "Football" : "Pokeball"

        print("DEBUG: Animating \(ballName) from \(startPos) to card at \(targetPosition)")

        // Calculate arc height based on distance
        let distance = simd_distance(startPos, targetPosition)
        let arcHeight = max(0.2, distance * 0.4)  // Arc proportional to distance

        // Animation duration based on distance
        let duration: Double = Double(min(max(distance * 0.8, 0.4), 1.2))

        Task {
            // Phase 1: Arc up and forward
            let midPoint = SIMD3<Float>(
                (startPos.x + targetPosition.x) / 2,
                max(startPos.y, targetPosition.y) + arcHeight,
                (startPos.z + targetPosition.z) / 2
            )

            var arcTransform = ball.transform
            arcTransform.translation = midPoint
            // Spin the ball
            arcTransform.rotation = simd_quatf(angle: .pi, axis: SIMD3<Float>(1, 0.3, 0))
            ball.move(to: arcTransform, relativeTo: nil, duration: duration * 0.5, timingFunction: .easeOut)

            try? await Task.sleep(for: .seconds(duration * 0.5))

            // Phase 2: Descend to card
            var landTransform = ball.transform
            landTransform.translation = SIMD3<Float>(targetPosition.x, targetPosition.y + 0.02, targetPosition.z)
            landTransform.rotation = simd_quatf(angle: .pi * 2, axis: SIMD3<Float>(1, 0.3, 0))
            ball.move(to: landTransform, relativeTo: nil, duration: duration * 0.5, timingFunction: .easeIn)

            try? await Task.sleep(for: .seconds(duration * 0.5))

            statusMessage = "\(ballName) landed on card!"
            print("DEBUG: Ball landed on card at \(targetPosition)")

            // Small bounce
            var bounceUp = ball.transform
            bounceUp.translation.y += 0.03
            ball.move(to: bounceUp, relativeTo: nil, duration: 0.1, timingFunction: .easeOut)
            try? await Task.sleep(for: .seconds(0.1))

            var bounceDown = ball.transform
            bounceDown.translation.y = targetPosition.y + 0.015
            ball.move(to: bounceDown, relativeTo: nil, duration: 0.08, timingFunction: .easeIn)
            try? await Task.sleep(for: .seconds(0.1))

            // Final landing position is on top of the card
            let landPosition = SIMD3<Float>(targetPosition.x, targetPosition.y + 0.01, targetPosition.z)

            await MainActor.run {
                self.handlePokeballLanded(at: landPosition)
            }
        }
    }

    private func handlePokeballLanded(at position: SIMD3<Float>) {
        guard let arView else { return }

        // Stop tracking timer
        throwModeTimer?.invalidate()
        throwModeTimer = nil

        isThrowMode = false
        isReadyToThrow = false
        isPokeballAnimating = true

        let creature = availableCreatures[selectedCreatureIndex]
        let ballType = SpawnBallService.ballType(for: creature)
        let ballName = ballType == .football ? "Football" : "Pokeball"
        statusMessage = "\(ballName) landed!"

        // Clean up the thrown ball completely
        throwablePokeball?.removeFromParent()
        throwablePokeball = nil

        // Calculate distance from camera to landing position for scale adjustment
        let cameraTransform = arView.cameraTransform
        let cameraPos = SIMD3<Float>(
            cameraTransform.matrix.columns.3.x,
            cameraTransform.matrix.columns.3.y,
            cameraTransform.matrix.columns.3.z
        )
        let distance = simd_distance(cameraPos, position)
        print("DEBUG: Creature spawn distance from camera: \(distance)m")

        // Calculate adaptive scale based on distance
        // At 0.5m: scale = 0.5x, at 1.5m: scale = 1.0x, at 3m+: scale = 1.5x
        let distanceScale: Float
        if distance < 0.5 {
            distanceScale = 0.4  // Very close - make it small
        } else if distance < 1.0 {
            distanceScale = 0.4 + (distance - 0.5) * 0.8  // 0.4 to 0.8
        } else if distance < 2.0 {
            distanceScale = 0.8 + (distance - 1.0) * 0.2  // 0.8 to 1.0
        } else {
            distanceScale = min(1.2, 1.0 + (distance - 2.0) * 0.1)  // 1.0 to 1.2 max
        }
        print("DEBUG: Using distance scale multiplier: \(distanceScale)")

        // Remove old anchor
        if let oldAnchor = creatureAnchor {
            arView.scene.removeAnchor(oldAnchor)
            creatureAnchor = nil
        }

        // Create anchor at landing position (on the floor)
        let landTransform = simd_float4x4(
            SIMD4<Float>(1, 0, 0, 0),
            SIMD4<Float>(0, 1, 0, 0),
            SIMD4<Float>(0, 0, 1, 0),
            SIMD4<Float>(position.x, position.y, position.z, 1)
        )

        let anchor = AnchorEntity(world: landTransform)
        arView.scene.addAnchor(anchor)
        creatureAnchor = anchor

        currentCreature = creature
        currentCreatureScale = creature.modelScale * distanceScale

        // Set HP based on creature element
        switch creature.element {
        case .fire: creatureMaxHP = 120; creatureHP = 120
        case .ice: creatureMaxHP = 100; creatureHP = 100
        case .nature: creatureMaxHP = 90; creatureHP = 90
        case .sports: creatureMaxHP = 110; creatureHP = 110
        }

        let scaleMultiplier = distanceScale  // Capture for async context

        Task {
            if let ball = await SpawnBallService.loadBall(for: creature) {
                pokeballEntity = ball
                ball.position = SIMD3<Float>(0, 0.02, 0)
                ball.scale = SIMD3<Float>(repeating: ballType.landedScale)
                anchor.addChild(ball)

                await SpawnBallService.runSpawnSequence(
                    ball: ball,
                    anchor: anchor,
                    creature: creature,
                    scaleMultiplier: scaleMultiplier,
                    onBallLanded: {
                        self.statusMessage = "\(ballName) is opening..."
                    },
                    onCreatureReady: { entity in
                        self.creatureEntity = entity
                        self.isCreatureSpawned = true
                        self.isPokeballAnimating = false
                        self.throwablePokeball = nil
                        self.statusMessage = "\(creature.name) appeared! HP: \(self.creatureHP)/\(self.creatureMaxHP)"
                        self.startIdleLoop()

                        // Clean up dropped card if we were in card drop mode
                        if self.isCardDropMode {
                            self.droppedCardEntity?.removeFromParent()
                            self.droppedCardEntity = nil
                            if let cardAnchor = self.droppedCardAnchor {
                                self.arView?.scene.removeAnchor(cardAnchor)
                                self.droppedCardAnchor = nil
                            }
                            self.isCardDropMode = false
                            self.isCardOnSurface = false
                        }

                        // Show welcome speech bubble
                        self.showWelcomeSpeech(for: creature)
                    }
                )
            }
        }
    }

    // MARK: - Chat

    func showWelcomeSpeech(for creature: Creature) {
        let welcomeMessages: [Creature.Element: [String]] = [
            .fire: ["*ROAR* Finally, I'm free!", "Ready to battle!", "*breathes small flame*"],
            .ice: ["*crystals shimmer* Greetings...", "The cold embraces us.", "*frost swirls*"],
            .nature: ["*leaves rustle* Hello friend!", "Nature is beautiful today!", "*flowers bloom*"],
            .sports: ["¡Hola! Ready to play? ⚽", "*juggles ball* Vamos!", "The beautiful game awaits!"]
        ]

        if let messages = welcomeMessages[creature.element] {
            lastCharacterMessage = messages.randomElement() ?? "Hello!"
            showSpeechBubble = true

            Task { @MainActor in
                try? await Task.sleep(for: .seconds(4))
                showSpeechBubble = false
            }
        }
    }

    func openChat() {
        guard currentCreature != nil else { return }
        showChat = true
    }

    // MARK: - Reset

    func resetScene() {
        guard let arView else { return }

        idleTimer?.invalidate()
        idleTimer = nil
        throwModeTimer?.invalidate()
        throwModeTimer = nil

        for anchor in arView.scene.anchors {
            arView.scene.removeAnchor(anchor)
        }

        creatureEntity = nil
        pokeballEntity = nil
        creatureAnchor = nil
        currentCreature = nil
        isCreatureSpawned = false
        isAttacking = false
        isPokeballAnimating = false
        particleEntities = []
        detectedCardName = nil
        isCardDetected = false
        cardDetectionProgress = 0
        currentCreatureScale = 0.003
        creatureHP = 120
        creatureMaxHP = 120
        lastDamage = 0
        showDamageNumber = false
        showAttackFlash = false
        isTrackingCard = false
        isTrackingWithCard = false
        trackedImageAnchorID = nil
        isThrowMode = false
        isReadyToThrow = false
        throwablePokeball = nil
        showChat = false
        showSpeechBubble = false
        lastCharacterMessage = ""

        // Card drop mode state
        isCardDropMode = false
        isCardOnSurface = false
        waitingForSurface = false
        droppedCardEntity = nil
        droppedCardAnchor = nil

        statusMessage = "Point your camera at a CollectARble card"
        configureSession()
    }

    func cycleCreature() {
        guard !isCreatureSpawned else { return }
        selectedCreatureIndex = (selectedCreatureIndex + 1) % availableCreatures.count
    }

    // MARK: - Model Loading

    private func loadBundledModel(for creature: Creature) async -> Entity {
        // Try animation model first for more dynamic appearance
        if let animName = creature.animationModelName {
            do {
                let entity = try await ModelLoaderService.loadBundledModel(named: animName)
                return entity
            } catch {
                // Fall through to static model
            }
        }

        guard let modelName = creature.bundledModelName else {
            return CreatureBuilder.buildCreature(for: creature)
        }
        do {
            let entity = try await ModelLoaderService.loadBundledModel(named: modelName)
            return entity
        } catch {
            return CreatureBuilder.buildCreature(for: creature)
        }
    }

    // MARK: - Idle Animation

    private func startIdleLoop() {
        idleTimer?.invalidate()
        idlePhase = 0

        // Smooth continuous bob: alternate between floating up and drifting down
        // Keep within card bounds — small bob range
        idleTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            guard let self, let entity = self.creatureEntity, let anchor = self.creatureAnchor else { return }
            self.idlePhase += 1

            let baseY: Float = 0.002
            let bobHeight: Float = 0.001
            let targetY = (Int(self.idlePhase) % 2 == 0) ? baseY + bobHeight : baseY

            var target = entity.transform
            target.translation.y = targetY
            // Keep current rotation without adding wobble to prevent drift
            entity.move(to: target, relativeTo: anchor, duration: 1.4, timingFunction: .easeInOut)
        }

        // Start the first bob immediately
        if let entity = creatureEntity, let anchor = creatureAnchor {
            var target = entity.transform
            target.translation.y = 0.002 + 0.001
            entity.move(to: target, relativeTo: anchor, duration: 1.4, timingFunction: .easeInOut)
        }
    }

    // MARK: - Card Image Loading

    /// Load card image from bundle - same approach as CardCollectionView.loadBundleImage
    private func loadCardImage(named name: String) -> UIImage? {
        guard !name.isEmpty else { return nil }

        // Try multiple extensions (same as CardCollectionView)
        let extensions = ["png", "jpg", "jpeg"]
        for ext in extensions {
            if let path = Bundle.main.path(forResource: name, ofType: ext) {
                print("DEBUG: Found card image path: \(path)")
                if let image = UIImage(contentsOfFile: path) {
                    print("DEBUG: Successfully loaded card image \(name): \(image.size)")
                    return image
                }
            }
        }

        // Try loading from asset catalog as fallback
        if let image = UIImage(named: name) {
            print("DEBUG: Loaded \(name) from asset catalog: \(image.size)")
            return image
        }

        print("DEBUG: Could not find card image: \(name)")
        return nil
    }

    /// Crop image to target aspect ratio (center crop)
    private func cropImageToAspectRatio(_ image: UIImage, targetAspect: CGFloat) -> UIImage {
        let imageSize = image.size
        let imageAspect = imageSize.width / imageSize.height

        // If aspect ratios match (within tolerance), return original
        if abs(imageAspect - targetAspect) < 0.01 {
            return image
        }

        var cropRect: CGRect

        if imageAspect > targetAspect {
            // Image is wider than target - crop width
            let newWidth = imageSize.height * targetAspect
            let xOffset = (imageSize.width - newWidth) / 2
            cropRect = CGRect(x: xOffset, y: 0, width: newWidth, height: imageSize.height)
        } else {
            // Image is taller than target - crop height
            let newHeight = imageSize.width / targetAspect
            let yOffset = (imageSize.height - newHeight) / 2
            cropRect = CGRect(x: 0, y: yOffset, width: imageSize.width, height: newHeight)
        }

        // Perform the crop
        guard let cgImage = image.cgImage,
              let croppedCGImage = cgImage.cropping(to: cropRect) else {
            return image
        }

        return UIImage(cgImage: croppedCGImage, scale: image.scale, orientation: image.imageOrientation)
    }
}
