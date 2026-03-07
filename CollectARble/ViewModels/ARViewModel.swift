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
        statusMessage = "Card detected! Summoning creature..."

        beginSpawn(at: imageAnchor.transform)
    }

    func handleImageAnchorUpdated(_ imageAnchor: ARImageAnchor) {
        // Update tracking state
        if imageAnchor.identifier == trackedImageAnchorID {
            isTrackingCard = imageAnchor.isTracked
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

    // MARK: - Spawning

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
        let rotationSpeed: Float = 0.01
        let yaw = Float(translation.x) * rotationSpeed
        let currentRotation = entity.transform.rotation
        let deltaRotation = simd_quatf(angle: yaw, axis: SIMD3<Float>(0, 1, 0))
        entity.transform.rotation = deltaRotation * currentRotation
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
                statusMessage = "\(creature.name) fainted! Tap reset to try again"
                creatureHP = creatureMaxHP
            } else {
                statusMessage = "\(creature.name) — HP: \(creatureHP)/\(creatureMaxHP)"
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
            // First, verify we can find a floor
            if let cameraTransform = arView.session.currentFrame?.camera.transform {
                let floorY = PokeballThrowService.findFloorLevel(arView: arView, cameraTransform: cameraTransform)
                let cameraY = cameraTransform.columns.3.y
                let floorDistance = cameraY - floorY

                if floorDistance > 0.3 && floorDistance < 3.0 {
                    statusMessage = "Swipe forward to throw the \(ballName)!"
                } else {
                    statusMessage = "Point at floor, then swipe to throw!"
                }
                print("DEBUG: Floor detected at \(floorY), camera at \(cameraY), distance: \(floorDistance)m")
            }

            if let cameraTransform = arView.session.currentFrame?.camera.transform,
               let ball = await PokeballThrowService.createThrowableBall(for: creature, at: cameraTransform) {
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
                  let cameraTransform = self.arView?.session.currentFrame?.camera.transform else {
                return
            }
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

    func handleThrowGesture(velocity: CGPoint) {
        print("DEBUG: handleThrowGesture called with velocity \(velocity)")
        guard isThrowMode, isReadyToThrow,
              let arView,
              let ball = throwablePokeball,
              let cameraTransform = arView.session.currentFrame?.camera.transform else {
            print("DEBUG: Throw guard failed - isThrowMode:\(isThrowMode) isReadyToThrow:\(isReadyToThrow)")
            return
        }

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

        // Find the floor level with comprehensive detection
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

        // Set HP based on creature element
        switch creature.element {
        case .fire: creatureMaxHP = 120; creatureHP = 120
        case .ice: creatureMaxHP = 100; creatureHP = 100
        case .nature: creatureMaxHP = 90; creatureHP = 90
        case .sports: creatureMaxHP = 110; creatureHP = 110
        }

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
        trackedImageAnchorID = nil
        isThrowMode = false
        isReadyToThrow = false
        throwablePokeball = nil
        showChat = false
        showSpeechBubble = false
        lastCharacterMessage = ""

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
}
