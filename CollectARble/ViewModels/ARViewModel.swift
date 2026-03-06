import SwiftUI
import RealityKit
import ARKit
import Combine

@Observable
class ARViewModel {
    var currentCreature: Creature?
    var isCreatureSpawned: Bool = false
    var isAttacking: Bool = false
    var statusMessage: String = "Point your camera at any trading card"
    var selectedCreatureIndex: Int = 0
    var detectedCardName: String?
    var isPokeballAnimating: Bool = false
    var isCardDetected: Bool = false
    var cardDetectionProgress: Float = 0

    private var creatureEntity: Entity?
    private var pokeballEntity: Entity?
    private var particleEntities: [Entity] = []
    private var arView: ARView?
    private var idleTimer: Timer?
    let cardDetectionService = CardDetectionService()
    private var cardHoldStartTime: TimeInterval?
    private let cardHoldDuration: TimeInterval = 1.0
    private var creatureAnchor: AnchorEntity?
    private var currentCreatureScale: Float = 0.0004
    private var lastCardWorldPosition: SIMD3<Float>?
    private var isTrackingCard: Bool = false

    var availableCreatures: [Creature] {
        Creature.allCreatures
    }

    func setARView(_ view: ARView) {
        arView = view
    }

    func configureSession() {
        guard let arView else { return }

        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        config.environmentTexturing = .automatic

        if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) {
            config.frameSemantics.insert(.personSegmentationWithDepth)
        }

        statusMessage = "Point your camera at any trading card"
        arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
    }

    func processFrame(_ frame: ARFrame) {
        guard let arView else { return }

        let viewportSize = arView.bounds.size
        guard viewportSize.width > 0, viewportSize.height > 0 else { return }

        if isCreatureSpawned, isTrackingCard {
            updateCreaturePositionFromCard(frame: frame, viewportSize: viewportSize)
            return
        }

        guard !isCreatureSpawned, !isPokeballAnimating else { return }

        if let detected = cardDetectionService.detectCard(in: frame, viewportSize: viewportSize) {
            if cardHoldStartTime == nil {
                cardHoldStartTime = frame.timestamp
                isCardDetected = true
                statusMessage = "Card detected! Hold steady..."
            }

            if let startTime = cardHoldStartTime {
                let elapsed = frame.timestamp - startTime
                cardDetectionProgress = min(Float(elapsed / cardHoldDuration), 1.0)

                if elapsed >= cardHoldDuration {
                    cardHoldStartTime = nil
                    cardDetectionProgress = 1.0
                    spawnCreatureOnCard(screenPoint: detected.screenCenter)
                }
            }
        } else {
            if cardHoldStartTime != nil {
                cardHoldStartTime = nil
                cardDetectionProgress = 0
                isCardDetected = false
                statusMessage = "Point your camera at any trading card"
            }
        }
    }

    private func updateCreaturePositionFromCard(frame: ARFrame, viewportSize: CGSize) {
        guard let anchor = creatureAnchor else { return }

        if let detected = cardDetectionService.detectCardPassive(in: frame, viewportSize: viewportSize) {
            guard let arView else { return }
            let results = arView.raycast(from: detected.screenCenter, allowing: .estimatedPlane, alignment: .horizontal)
            if let result = results.first {
                let newPos = SIMD3<Float>(
                    result.worldTransform.columns.3.x,
                    result.worldTransform.columns.3.y,
                    result.worldTransform.columns.3.z
                )
                let currentPos = anchor.position(relativeTo: nil)
                let smoothed = currentPos + (newPos - currentPos) * 0.15
                anchor.setPosition(smoothed, relativeTo: nil)
                lastCardWorldPosition = smoothed
            }
        }
    }

    private func spawnCreatureOnCard(screenPoint: CGPoint) {
        guard let arView, !isCreatureSpawned, !isPokeballAnimating else { return }

        let results = arView.raycast(from: screenPoint, allowing: .estimatedPlane, alignment: .horizontal)
        if let result = results.first {
            beginSpawn(at: result.worldTransform)
            return
        }

        let fallbackResults = arView.raycast(from: screenPoint, allowing: .existingPlaneGeometry, alignment: .horizontal)
        if let fallback = fallbackResults.first {
            beginSpawn(at: fallback.worldTransform)
            return
        }

        let anyResults = arView.raycast(from: screenPoint, allowing: .estimatedPlane, alignment: .any)
        if let anyResult = anyResults.first {
            beginSpawn(at: anyResult.worldTransform)
            return
        }

        statusMessage = "Move closer to the card on a flat surface"
        cardHoldStartTime = nil
        cardDetectionProgress = 0
        isCardDetected = false
    }

    private func beginSpawn(at worldTransform: simd_float4x4) {
        guard let arView else { return }

        let creature = availableCreatures[selectedCreatureIndex]
        currentCreature = creature
        detectedCardName = creature.id
        isPokeballAnimating = true
        isCardDetected = false
        cardDetectionProgress = 0

        let anchor = AnchorEntity(world: worldTransform)
        arView.scene.addAnchor(anchor)
        creatureAnchor = anchor
        lastCardWorldPosition = SIMD3<Float>(
            worldTransform.columns.3.x,
            worldTransform.columns.3.y,
            worldTransform.columns.3.z
        )

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
                        self.isTrackingCard = true
                        self.statusMessage = "\(creature.name) appeared! Interact with it!"
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
            isTrackingCard = true
            statusMessage = "\(creature.name) appeared! Interact with it!"
            startIdleLoop()
        } else {
            let entity = CreatureBuilder.buildCreature(for: creature)
            entity.position.y = 0.01
            anchor.addChild(entity)
            creatureEntity = entity
            isCreatureSpawned = true
            isPokeballAnimating = false
            isTrackingCard = true
            statusMessage = "\(creature.name) appeared!"
            CreatureBuilder.animateSpawn(entity: entity)
            startIdleLoop()
        }
    }

    func spawnCreature(at worldTransform: simd_float4x4) {
        guard !isCreatureSpawned, !isPokeballAnimating else { return }
        beginSpawn(at: worldTransform)
    }

    func handlePanGesture(translation: CGPoint) {
        guard let entity = creatureEntity, let anchor = creatureAnchor else { return }
        let rotationSpeed: Float = 0.008
        let yaw = Float(translation.x) * rotationSpeed
        let currentRotation = entity.transform.rotation
        let deltaRotation = simd_quatf(angle: yaw, axis: SIMD3<Float>(0, 1, 0))
        entity.transform.rotation = deltaRotation * currentRotation
    }

    func handlePinchBegan() {
    }

    func handlePinchGesture(scale: Float) {
        guard let entity = creatureEntity else { return }
        let newScale = currentCreatureScale * scale
        let clampedScale = min(max(newScale, 0.0001), 0.003)
        entity.scale = SIMD3<Float>(repeating: clampedScale)
    }

    func handlePinchEnd(scale: Float) {
        let newScale = currentCreatureScale * scale
        currentCreatureScale = min(max(newScale, 0.0001), 0.003)
    }

    func triggerAttack() {
        guard let creature = currentCreature,
              let entity = creatureEntity,
              let anchor = creatureAnchor,
              !isAttacking else { return }

        isAttacking = true
        statusMessage = "\(creature.attackName)!"

        let localPos = entity.position(relativeTo: anchor)

        let particles: [Entity]
        if creature.element == .fire {
            particles = ParticleEffectBuilder.createFlamethrowerEffect(at: localPos, parentAnchor: anchor)
        } else {
            particles = ParticleEffectBuilder.createAttackParticles(for: creature, at: localPos)
            for particle in particles {
                anchor.addChild(particle)
            }
        }

        particleEntities = particles

        Task {
            try? await Task.sleep(for: .seconds(1.5))
            for particle in particles {
                particle.removeFromParent()
            }
            particleEntities = []
            isAttacking = false
            statusMessage = "\(creature.name) is ready"
        }
    }

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
        isTrackingCard = false
        particleEntities = []
        detectedCardName = nil
        isCardDetected = false
        cardDetectionProgress = 0
        cardHoldStartTime = nil
        currentCreatureScale = 0.0004
        lastCardWorldPosition = nil
        cardDetectionService.reset()

        statusMessage = "Point your camera at any trading card"
        configureSession()
    }

    func cycleCreature() {
        guard !isCreatureSpawned else { return }
        selectedCreatureIndex = (selectedCreatureIndex + 1) % availableCreatures.count
    }

    private func loadBundledModel(for creature: Creature) async -> Entity {
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

    private func startIdleLoop() {
        idleTimer?.invalidate()
        idleTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            guard let self, let entity = self.creatureEntity else { return }
            CreatureBuilder.startIdleAnimation(entity: entity)
        }
        if let entity = creatureEntity {
            CreatureBuilder.startIdleAnimation(entity: entity)
        }
    }
}
