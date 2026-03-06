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

    private var creatureEntity: Entity?
    private var pokeballEntity: Entity?
    private var particleEntities: [Entity] = []
    private var arView: ARView?
    private var idleTimer: Timer?
    private var creatureAnchor: AnchorEntity?
    private var currentCreatureScale: Float = 0.0004
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

        if !referenceImages.isEmpty {
            // Primary: Use image tracking so creature sticks to the card
            let config = ARImageTrackingConfiguration()
            config.trackingImages = referenceImages
            config.maximumNumberOfTrackedImages = 1
            statusMessage = "Point your camera at a CollectARble card"
            arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
        } else {
            // Fallback: world tracking with plane detection
            let config = ARWorldTrackingConfiguration()
            config.planeDetection = [.horizontal]
            config.environmentTexturing = .automatic
            statusMessage = "Point at a flat surface and tap to place creature"
            arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
        }
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
        }

        let anchor = AnchorEntity(world: worldTransform)
        arView.scene.addAnchor(anchor)
        creatureAnchor = anchor

        statusMessage = "Summoning \(creature.name)!"

        Task {
            if let pokeball = await PokeballAnimationService.loadPokeball() {
                pokeballEntity = pokeball
                anchor.addChild(pokeball)
                statusMessage = "Pokéball incoming!"

                await PokeballAnimationService.runSpawnSequence(
                    pokeball: pokeball,
                    anchor: anchor,
                    creature: creature,
                    onPokeballLanded: {
                        self.statusMessage = "Pokéball is opening..."
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
            entity.position = SIMD3<Float>(0, 0.005, 0)
            anchor.addChild(entity)

            let targetScale: Float = 0.0004
            var target = entity.transform
            target.scale = SIMD3<Float>(repeating: targetScale)
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
            entity.position.y = 0.01
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
        let clampedScale = min(max(newScale, 0.0001), 0.005)
        entity.scale = SIMD3<Float>(repeating: clampedScale)
    }

    func handlePinchEnd(scale: Float) {
        let newScale = currentCreatureScale * scale
        currentCreatureScale = min(max(newScale, 0.0001), 0.005)
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

    // MARK: - Reset

    func resetScene() {
        guard let arView else { return }

        idleTimer?.invalidate()
        idleTimer = nil

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
        currentCreatureScale = 0.0004
        creatureHP = 120
        creatureMaxHP = 120
        lastDamage = 0
        showDamageNumber = false
        showAttackFlash = false
        isTrackingCard = false
        trackedImageAnchorID = nil

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
        idleTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            guard let self, let entity = self.creatureEntity, let anchor = self.creatureAnchor else { return }
            self.idlePhase += 1

            let baseY: Float = 0.005
            let bobHeight: Float = 0.015
            let targetY = (Int(self.idlePhase) % 2 == 0) ? baseY + bobHeight : baseY

            // Gentle rotation wobble
            let rotAngle: Float = (Int(self.idlePhase) % 2 == 0) ? 0.05 : -0.05

            var target = entity.transform
            target.translation.y = targetY
            target.rotation = simd_quatf(angle: rotAngle, axis: SIMD3<Float>(0, 0, 1)) * entity.transform.rotation
            entity.move(to: target, relativeTo: anchor, duration: 1.4, timingFunction: .easeInOut)
        }

        // Start the first bob immediately
        if let entity = creatureEntity, let anchor = creatureAnchor {
            var target = entity.transform
            target.translation.y = 0.005 + 0.015
            entity.move(to: target, relativeTo: anchor, duration: 1.4, timingFunction: .easeInOut)
        }
    }
}
