import RealityKit
import UIKit

struct PokeballAnimationService {
    static func loadPokeball() async -> Entity? {
        let names = ["Poke_Ball", "Pokeball", "poke_ball", "pokeball"]
        for name in names {
            if let url = Bundle.main.url(forResource: name, withExtension: "usdz") {
                do {
                    let entity = try await Entity(contentsOf: url)
                    entity.scale = SIMD3<Float>(repeating: 0.0001)  // Small but visible
                    entity.position = SIMD3<Float>(0, 0.05, 0)  // Start above surface
                    print("DEBUG: Loaded pokeball USDZ, initial scale \(entity.scale)")
                    return entity
                } catch {
                    print("DEBUG: Failed to load pokeball \(name): \(error)")
                    continue
                }
            }
        }
        print("DEBUG: Using fallback pokeball")
        return createFallbackPokeball()
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

        root.scale = SIMD3<Float>(repeating: 0.0001)  // Match USDZ scale
        root.position = SIMD3<Float>(0, 0.05, 0)  // Start above surface

        return root
    }

    static func runSpawnSequence(
        pokeball: Entity,
        anchor: Entity,
        creature: Creature,
        onPokeballLanded: @escaping () -> Void,
        onCreatureReady: @escaping (Entity) -> Void
    ) async {
        var landTransform = pokeball.transform
        landTransform.scale = SIMD3<Float>(repeating: 0.0002)  // Visible pokeball on surface
        landTransform.translation = SIMD3<Float>(0, 0.02, 0)  // Sit just above surface
        pokeball.move(to: landTransform, relativeTo: anchor, duration: 0.5, timingFunction: .easeIn)

        try? await Task.sleep(for: .seconds(0.55))
        onPokeballLanded()

        for i in 0..<3 {
            let angle: Float = (i % 2 == 0) ? 0.15 : -0.15
            var shakeTransform = pokeball.transform
            shakeTransform.rotation = simd_quatf(angle: angle, axis: SIMD3<Float>(0, 0, 1))
            pokeball.move(to: shakeTransform, relativeTo: anchor, duration: 0.12, timingFunction: .easeInOut)
            try? await Task.sleep(for: .seconds(0.15))
        }

        var resetRotation = pokeball.transform
        resetRotation.rotation = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
        pokeball.move(to: resetRotation, relativeTo: anchor, duration: 0.08, timingFunction: .easeOut)
        try? await Task.sleep(for: .seconds(0.1))

        // Create the flash at the pokéball position before shrinking it
        let pokeballPos = pokeball.position(relativeTo: anchor)
        let flashParticles = createOpenFlash(at: pokeballPos)
        for particle in flashParticles {
            anchor.addChild(particle)
        }

        // Rapidly shrink the pokéball to zero — the "burst open" moment
        var vanishTransform = pokeball.transform
        vanishTransform.scale = SIMD3<Float>(repeating: 0.00001)
        pokeball.move(to: vanishTransform, relativeTo: anchor, duration: 0.2, timingFunction: .easeIn)

        // Expanding energy sphere at the open point - use creature's element color
        var energyMaterial = SimpleMaterial()
        energyMaterial.color = .init(tint: creature.element.primaryColor.withAlphaComponent(0.7))
        energyMaterial.metallic = .init(floatLiteral: 0.0)  // Non-metallic for soft glow
        energyMaterial.roughness = .init(floatLiteral: 0.8)  // Rough for diffuse light

        let energySphere = ModelEntity(
            mesh: .generateSphere(radius: 0.003),
            materials: [energyMaterial]
        )
        energySphere.position = pokeballPos + SIMD3<Float>(0, 0.005, 0)
        anchor.addChild(energySphere)

        var sphereExpand = energySphere.transform
        sphereExpand.scale = SIMD3<Float>(repeating: 4.0)  // Slightly smaller expansion
        energySphere.move(to: sphereExpand, relativeTo: anchor, duration: 0.25, timingFunction: .easeOut)

        // Radial energy ring burst
        let ringParticles = createEnergyRing(at: pokeballPos + SIMD3<Float>(0, 0.01, 0), color: creature.element.primaryColor)
        for particle in ringParticles {
            anchor.addChild(particle)
        }

        try? await Task.sleep(for: .seconds(0.3))

        // Fade out the energy sphere
        var sphereFade = energySphere.transform
        sphereFade.scale = SIMD3<Float>(repeating: 0.01)
        energySphere.move(to: sphereFade, relativeTo: anchor, duration: 0.4, timingFunction: .easeIn)

        try? await Task.sleep(for: .seconds(0.1))

        if creature.bundledModelName != nil {
            let creatureEntity = await loadCreatureModel(for: creature)
            creatureEntity.scale = SIMD3<Float>(repeating: 0.0001)
            creatureEntity.position = SIMD3<Float>(0, 0, 0)  // Start at anchor level
            anchor.addChild(creatureEntity)

            // Scale creature based on creature's defined scale
            let targetScale: Float = creature.modelScale
            print("DEBUG: PokeballService spawning creature at scale \(targetScale)")
            var creatureTarget = creatureEntity.transform
            creatureTarget.scale = SIMD3<Float>(repeating: targetScale)
            creatureTarget.translation = SIMD3<Float>(0, 0, 0)  // On the surface
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

            // Clean up all particles and pokéball
            for particle in flashParticles + burstParticles + ringParticles + [energySphere] {
                particle.removeFromParent()
            }
            pokeball.removeFromParent()
        } else {
            let creatureEntity = CreatureBuilder.buildCreature(for: creature)
            creatureEntity.position.y = 0.005
            anchor.addChild(creatureEntity)
            CreatureBuilder.animateSpawn(entity: creatureEntity)

            onCreatureReady(creatureEntity)

            try? await Task.sleep(for: .seconds(0.8))

            // Clean up all particles and pokéball
            for particle in flashParticles + ringParticles + [energySphere] {
                particle.removeFromParent()
            }
            pokeball.removeFromParent()
        }
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

        // Try each model in shuffled order
        for selectedModel in shuffledModels {
            let names = [selectedModel, selectedModel.replacingOccurrences(of: "_", with: "")]
            for name in names {
                if let url = Bundle.main.url(forResource: name, withExtension: "usdz") {
                    do {
                        return try await Entity(contentsOf: url)
                    } catch {
                        continue
                    }
                }
            }
        }

        return CreatureBuilder.buildCreature(for: creature)
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

    private static func createOpenFlash(at position: SIMD3<Float>) -> [Entity] {
        var particles: [Entity] = []
        // Non-metallic materials for soft glow particles
        var whiteMat = SimpleMaterial()
        whiteMat.color = .init(tint: .white.withAlphaComponent(0.9))
        whiteMat.metallic = .init(floatLiteral: 0.0)
        whiteMat.roughness = .init(floatLiteral: 0.6)

        var yellowMat = SimpleMaterial()
        yellowMat.color = .init(tint: UIColor(red: 1, green: 0.95, blue: 0.7, alpha: 0.9))
        yellowMat.metallic = .init(floatLiteral: 0.0)
        yellowMat.roughness = .init(floatLiteral: 0.6)

        for i in 0..<12 {
            let angle = Float(i) / 12.0 * .pi * 2
            let material = i % 2 == 0 ? whiteMat : yellowMat
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
