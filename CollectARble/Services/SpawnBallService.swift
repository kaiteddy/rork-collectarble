import RealityKit
import UIKit

/// Service for loading and animating spawn balls (pokeball, football, etc.) based on creature type
struct SpawnBallService {

    enum BallType {
        case pokeball
        case football

        var modelNames: [String] {
            switch self {
            case .pokeball:
                return ["Poke_Ball", "Pokeball", "poke_ball", "pokeball"]
            case .football:
                return ["Football", "football", "Soccer_Ball", "soccer_ball"]
            }
        }

        var throwScale: Float {
            switch self {
            case .pokeball: return 0.0003
            case .football: return 0.0003  // Match pokeball scale
            }
        }

        var landedScale: Float {
            switch self {
            case .pokeball: return 0.0002
            case .football: return 0.0002  // Match pokeball scale
            }
        }

        var spawnScale: Float {
            switch self {
            case .pokeball: return 0.0001
            case .football: return 0.0001  // Match pokeball scale
            }
        }
    }

    /// Determine ball type based on creature element
    static func ballType(for creature: Creature) -> BallType {
        switch creature.element {
        case .sports:
            return .football
        case .fire, .ice, .nature:
            return .pokeball
        }
    }

    /// Load the appropriate ball for a creature
    static func loadBall(for creature: Creature) async -> Entity? {
        let type = ballType(for: creature)
        return await loadBall(type: type)
    }

    /// Load a ball by type (position should be set by caller)
    static func loadBall(type: BallType) async -> Entity? {
        for name in type.modelNames {
            if let url = Bundle.main.url(forResource: name, withExtension: "usdz") {
                do {
                    let entity = try await Entity(contentsOf: url)
                    entity.scale = SIMD3<Float>(repeating: type.spawnScale)
                    entity.position = SIMD3<Float>(0, 0, 0)  // Reset to origin, caller sets position
                    print("DEBUG: Loaded \(type) USDZ '\(name)', scale \(entity.scale)")
                    return entity
                } catch {
                    print("DEBUG: Failed to load \(name): \(error)")
                    continue
                }
            }
        }

        // Fallback
        print("DEBUG: Using fallback for \(type)")
        return createFallback(type: type)
    }

    private static func createFallback(type: BallType) -> Entity {
        switch type {
        case .pokeball:
            return createFallbackPokeball()
        case .football:
            return createFallbackFootball()
        }
    }

    private static func createFallbackPokeball() -> Entity {
        let root = Entity()
        root.name = "FallbackPokeball"

        let topHalf = ModelEntity(
            mesh: .generateSphere(radius: 0.012),
            materials: [SimpleMaterial(color: .red, roughness: 0.3, isMetallic: true)]
        )
        topHalf.position = SIMD3<Float>(0, 0.003, 0)

        let bottomHalf = ModelEntity(
            mesh: .generateSphere(radius: 0.012),
            materials: [SimpleMaterial(color: .white, roughness: 0.3, isMetallic: true)]
        )
        bottomHalf.position = SIMD3<Float>(0, -0.003, 0)

        let band = ModelEntity(
            mesh: .generateCylinder(height: 0.002, radius: 0.013),
            materials: [SimpleMaterial(color: .darkGray, roughness: 0.5, isMetallic: false)]
        )

        let button = ModelEntity(
            mesh: .generateSphere(radius: 0.004),
            materials: [SimpleMaterial(color: .white, roughness: 0.1, isMetallic: true)]
        )
        button.position = SIMD3<Float>(0, 0, 0.012)

        root.addChild(topHalf)
        root.addChild(bottomHalf)
        root.addChild(band)
        root.addChild(button)

        root.scale = SIMD3<Float>(repeating: BallType.pokeball.spawnScale)
        root.position = SIMD3<Float>(0, 0, 0)  // Caller sets position

        return root
    }

    private static func createFallbackFootball() -> Entity {
        let root = Entity()
        root.name = "FallbackFootball"

        // Main ball - white with black pentagons pattern (simplified)
        let ball = ModelEntity(
            mesh: .generateSphere(radius: 0.015),
            materials: [SimpleMaterial(color: .white, roughness: 0.4, isMetallic: false)]
        )
        root.addChild(ball)

        // Add black pentagon patches (simplified as small spheres)
        let patchColor = SimpleMaterial(color: .black, roughness: 0.5, isMetallic: false)
        let patchPositions: [SIMD3<Float>] = [
            SIMD3<Float>(0, 0.014, 0),      // Top
            SIMD3<Float>(0, -0.014, 0),     // Bottom
            SIMD3<Float>(0.014, 0, 0),      // Right
            SIMD3<Float>(-0.014, 0, 0),     // Left
            SIMD3<Float>(0, 0, 0.014),      // Front
            SIMD3<Float>(0, 0, -0.014),     // Back
        ]

        for pos in patchPositions {
            let patch = ModelEntity(
                mesh: .generateSphere(radius: 0.004),
                materials: [patchColor]
            )
            patch.position = pos
            root.addChild(patch)
        }

        root.scale = SIMD3<Float>(repeating: BallType.football.spawnScale)
        root.position = SIMD3<Float>(0, 0, 0)  // Caller sets position

        return root
    }

    /// Run the spawn animation sequence
    static func runSpawnSequence(
        ball: Entity,
        anchor: Entity,
        creature: Creature,
        scaleMultiplier: Float = 1.0,
        onBallLanded: @escaping () -> Void,
        onCreatureReady: @escaping (Entity) -> Void
    ) async {
        let type = ballType(for: creature)

        // Land the ball
        var landTransform = ball.transform
        landTransform.scale = SIMD3<Float>(repeating: type.landedScale)
        landTransform.translation = SIMD3<Float>(0, 0.02, 0)
        ball.move(to: landTransform, relativeTo: anchor, duration: 0.5, timingFunction: .easeIn)

        try? await Task.sleep(for: .seconds(0.55))
        onBallLanded()

        // Different animations based on ball type
        switch type {
        case .pokeball:
            await runPokeballShake(ball: ball, anchor: anchor)
        case .football:
            await runFootballBounce(ball: ball, anchor: anchor)
        }

        // Reset rotation
        var resetRotation = ball.transform
        resetRotation.rotation = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
        ball.move(to: resetRotation, relativeTo: anchor, duration: 0.08, timingFunction: .easeOut)
        try? await Task.sleep(for: .seconds(0.1))

        // Create flash and spawn creature
        await spawnCreatureFromBall(ball: ball, anchor: anchor, creature: creature, scaleMultiplier: scaleMultiplier, onCreatureReady: onCreatureReady)
    }

    private static func runPokeballShake(ball: Entity, anchor: Entity) async {
        for i in 0..<3 {
            let angle: Float = (i % 2 == 0) ? 0.15 : -0.15
            var shakeTransform = ball.transform
            shakeTransform.rotation = simd_quatf(angle: angle, axis: SIMD3<Float>(0, 0, 1))
            ball.move(to: shakeTransform, relativeTo: anchor, duration: 0.12, timingFunction: .easeInOut)
            try? await Task.sleep(for: .seconds(0.15))
        }
    }

    private static func runFootballBounce(ball: Entity, anchor: Entity) async {
        // Football bounces and spins
        for i in 0..<3 {
            // Bounce up
            var bounceUp = ball.transform
            bounceUp.translation.y += 0.03 * (1.0 - Float(i) * 0.25)  // Decreasing height
            bounceUp.rotation = simd_quatf(angle: Float.pi * Float(i + 1) * 0.5, axis: SIMD3<Float>(1, 0.3, 0))
            ball.move(to: bounceUp, relativeTo: anchor, duration: 0.15, timingFunction: .easeOut)
            try? await Task.sleep(for: .seconds(0.15))

            // Bounce down
            var bounceDown = ball.transform
            bounceDown.translation.y = 0.02
            ball.move(to: bounceDown, relativeTo: anchor, duration: 0.1, timingFunction: .easeIn)
            try? await Task.sleep(for: .seconds(0.12))
        }
    }

    private static func spawnCreatureFromBall(
        ball: Entity,
        anchor: Entity,
        creature: Creature,
        scaleMultiplier: Float = 1.0,
        onCreatureReady: @escaping (Entity) -> Void
    ) async {
        let ballPos = ball.position(relativeTo: anchor)
        let flashParticles = createOpenFlash(at: ballPos, color: creature.element.primaryColor)
        for particle in flashParticles {
            anchor.addChild(particle)
        }

        // Shrink the ball
        var vanishTransform = ball.transform
        vanishTransform.scale = SIMD3<Float>(repeating: 0.00001)
        ball.move(to: vanishTransform, relativeTo: anchor, duration: 0.2, timingFunction: .easeIn)

        // Energy sphere - use creature's element color with glow-like appearance
        var energyMaterial = SimpleMaterial()
        energyMaterial.color = .init(tint: creature.element.primaryColor.withAlphaComponent(0.7))
        energyMaterial.metallic = .init(floatLiteral: 0.0)  // Non-metallic for soft glow
        energyMaterial.roughness = .init(floatLiteral: 0.8)  // Rough for diffuse light

        let energySphere = ModelEntity(
            mesh: .generateSphere(radius: 0.003),
            materials: [energyMaterial]
        )
        energySphere.position = ballPos + SIMD3<Float>(0, 0.005, 0)
        anchor.addChild(energySphere)

        var sphereExpand = energySphere.transform
        sphereExpand.scale = SIMD3<Float>(repeating: 4.0)  // Slightly smaller expansion
        energySphere.move(to: sphereExpand, relativeTo: anchor, duration: 0.25, timingFunction: .easeOut)

        // Energy ring
        let ringParticles = createEnergyRing(at: ballPos + SIMD3<Float>(0, 0.01, 0), color: creature.element.primaryColor)
        for particle in ringParticles {
            anchor.addChild(particle)
        }

        try? await Task.sleep(for: .seconds(0.3))

        // Fade energy sphere
        var sphereFade = energySphere.transform
        sphereFade.scale = SIMD3<Float>(repeating: 0.01)
        energySphere.move(to: sphereFade, relativeTo: anchor, duration: 0.4, timingFunction: .easeIn)

        try? await Task.sleep(for: .seconds(0.1))

        // Spawn creature
        let creatureEntity: Entity
        if creature.bundledModelName != nil {
            creatureEntity = await loadCreatureModel(for: creature)
        } else {
            creatureEntity = CreatureBuilder.buildCreature(for: creature)
        }

        creatureEntity.scale = SIMD3<Float>(repeating: 0.0001)
        creatureEntity.position = SIMD3<Float>(0, 0, 0)
        anchor.addChild(creatureEntity)

        let targetScale: Float = creature.modelScale * scaleMultiplier
        print("DEBUG: Spawning creature with scale \(targetScale) (base: \(creature.modelScale), multiplier: \(scaleMultiplier))")
        var creatureTarget = creatureEntity.transform
        creatureTarget.scale = SIMD3<Float>(repeating: targetScale)
        creatureTarget.translation = SIMD3<Float>(0, 0, 0)
        creatureEntity.move(to: creatureTarget, relativeTo: anchor, duration: 0.6, timingFunction: .easeOut)

        let burstParticles = createEnergyBurst(
            at: SIMD3<Float>(0, 0.01, 0),
            color: creature.element.primaryColor,
            secondaryColor: creature.element.secondaryColor
        )
        for particle in burstParticles {
            anchor.addChild(particle)
        }

        try? await Task.sleep(for: .seconds(0.6))

        for animation in creatureEntity.availableAnimations {
            creatureEntity.playAnimation(animation.repeat())
        }

        onCreatureReady(creatureEntity)

        try? await Task.sleep(for: .seconds(0.8))

        // Cleanup
        for particle in flashParticles + burstParticles + ringParticles + [energySphere] {
            particle.removeFromParent()
        }
        ball.removeFromParent()
    }

    private static func loadCreatureModel(for creature: Creature) async -> Entity {
        guard let modelName = creature.bundledModelName else {
            return CreatureBuilder.buildCreature(for: creature)
        }

        // Build list of available models - randomly select for variety
        var availableModels: [String] = [modelName]
        if let animationModel = creature.animationModelName {
            availableModels.append(animationModel)
        }

        // Randomly shuffle to provide different experiences
        let shuffledModels = availableModels.shuffled()
        print("DEBUG: Available models for \(creature.name): \(availableModels), selected order: \(shuffledModels)")

        // Try each model in shuffled order
        for selectedModel in shuffledModels {
            let names = [selectedModel, selectedModel.replacingOccurrences(of: "_", with: "")]
            for name in names {
                if let url = Bundle.main.url(forResource: name, withExtension: "usdz") {
                    do {
                        let entity = try await Entity(contentsOf: url)
                        print("DEBUG: Loaded model: \(name)")
                        return entity
                    } catch {
                        print("DEBUG: Failed to load \(name): \(error)")
                        continue
                    }
                }
            }
        }

        return CreatureBuilder.buildCreature(for: creature)
    }

    private static func createOpenFlash(at position: SIMD3<Float>, color: UIColor) -> [Entity] {
        var particles: [Entity] = []
        // Use non-metallic materials for a soft glow effect
        var whiteMat = SimpleMaterial()
        whiteMat.color = .init(tint: .white.withAlphaComponent(0.9))
        whiteMat.metallic = .init(floatLiteral: 0.0)
        whiteMat.roughness = .init(floatLiteral: 0.6)

        var coloredMat = SimpleMaterial()
        coloredMat.color = .init(tint: color.withAlphaComponent(0.9))
        coloredMat.metallic = .init(floatLiteral: 0.0)
        coloredMat.roughness = .init(floatLiteral: 0.6)

        for i in 0..<12 {
            let angle = Float(i) / 12.0 * .pi * 2
            let material = i % 2 == 0 ? whiteMat : coloredMat
            let particle = ModelEntity(
                mesh: .generateSphere(radius: 0.002),
                materials: [material]
            )
            particle.position = position + SIMD3<Float>(0, 0.005, 0)

            let spread: Float = 0.03
            let height = Float.random(in: 0.01...0.03)
            var target = particle.transform
            target.translation = position + SIMD3<Float>(cos(angle) * spread, height, sin(angle) * spread)
            target.scale = SIMD3<Float>(repeating: 0.3)
            particle.move(to: target, relativeTo: nil, duration: 0.5, timingFunction: .easeOut)

            particles.append(particle)
        }

        let glowBall = ModelEntity(
            mesh: .generateSphere(radius: 0.006),
            materials: [whiteMat]
        )
        glowBall.position = position + SIMD3<Float>(0, 0.01, 0)

        var glowTarget = glowBall.transform
        glowTarget.scale = SIMD3<Float>(repeating: 2.0)
        glowTarget.translation = position + SIMD3<Float>(0, 0.015, 0)
        glowBall.move(to: glowTarget, relativeTo: nil, duration: 0.4, timingFunction: .easeOut)
        particles.append(glowBall)

        return particles
    }

    private static func createEnergyRing(at position: SIMD3<Float>, color: UIColor) -> [Entity] {
        var particles: [Entity] = []
        // Non-metallic materials for soft glow particles
        var coloredMat = SimpleMaterial()
        coloredMat.color = .init(tint: color.withAlphaComponent(0.85))
        coloredMat.metallic = .init(floatLiteral: 0.0)
        coloredMat.roughness = .init(floatLiteral: 0.5)

        var whiteMat = SimpleMaterial()
        whiteMat.color = .init(tint: .white.withAlphaComponent(0.85))
        whiteMat.metallic = .init(floatLiteral: 0.0)
        whiteMat.roughness = .init(floatLiteral: 0.5)

        for i in 0..<20 {
            let angle = Float(i) / 20.0 * .pi * 2
            let mat = i % 3 == 0 ? whiteMat : coloredMat
            let size = Float.random(in: 0.001...0.0025)
            let particle = ModelEntity(
                mesh: .generateSphere(radius: size),
                materials: [mat]
            )
            particle.position = position

            let spread = Float.random(in: 0.025...0.04)
            let height = Float.random(in: -0.005...0.01)
            var target = particle.transform
            target.translation = position + SIMD3<Float>(cos(angle) * spread, height, sin(angle) * spread)
            target.scale = SIMD3<Float>(repeating: 0.1)
            let duration = Double.random(in: 0.3...0.5)
            particle.move(to: target, relativeTo: nil, duration: duration, timingFunction: .easeOut)

            particles.append(particle)
        }

        return particles
    }

    private static func createEnergyBurst(
        at position: SIMD3<Float>,
        color: UIColor,
        secondaryColor: UIColor
    ) -> [Entity] {
        var particles: [Entity] = []
        // Non-metallic materials for soft glow particles
        var primaryMat = SimpleMaterial()
        primaryMat.color = .init(tint: color.withAlphaComponent(0.85))
        primaryMat.metallic = .init(floatLiteral: 0.0)
        primaryMat.roughness = .init(floatLiteral: 0.5)

        var secondaryMat = SimpleMaterial()
        secondaryMat.color = .init(tint: secondaryColor.withAlphaComponent(0.85))
        secondaryMat.metallic = .init(floatLiteral: 0.0)
        secondaryMat.roughness = .init(floatLiteral: 0.5)

        for i in 0..<16 {
            let angle = Float(i) / 16.0 * .pi * 2
            let material = i % 3 == 0 ? secondaryMat : primaryMat
            let size = Float.random(in: 0.001...0.003)
            let particle = ModelEntity(
                mesh: .generateSphere(radius: size),
                materials: [material]
            )
            particle.position = position

            let spread = Float.random(in: 0.02...0.04)
            let height = Float.random(in: 0.01...0.04)
            var target = particle.transform
            target.translation = position + SIMD3<Float>(cos(angle) * spread, height, sin(angle) * spread)
            target.scale = SIMD3<Float>(repeating: 0.2)
            let duration = Double.random(in: 0.3...0.6)
            particle.move(to: target, relativeTo: nil, duration: duration, timingFunction: .easeOut)

            particles.append(particle)
        }

        return particles
    }
}
