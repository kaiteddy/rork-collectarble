import RealityKit
import UIKit

struct PokeballAnimationService {
    static func loadPokeball() async -> Entity? {
        let names = ["Poke_Ball", "Pokeball", "poke_ball", "pokeball"]
        for name in names {
            if let url = Bundle.main.url(forResource: name, withExtension: "usdz") {
                do {
                    let entity = try await Entity(contentsOf: url)
                    entity.scale = SIMD3<Float>(repeating: 0.0001)
                    entity.position = SIMD3<Float>(0, 0.15, 0)
                    return entity
                } catch {
                    continue
                }
            }
        }
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

        root.scale = SIMD3<Float>(repeating: 0.0001)
        root.position = SIMD3<Float>(0, 0.15, 0)

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
        landTransform.scale = SIMD3<Float>(repeating: 0.006)
        landTransform.translation = SIMD3<Float>(0, 0.01, 0)
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

        let flashParticles = createOpenFlash(at: pokeball.position(relativeTo: anchor))
        for particle in flashParticles {
            anchor.addChild(particle)
        }

        var openBurstTransform = pokeball.transform
        openBurstTransform.scale = SIMD3<Float>(repeating: 0.009)
        pokeball.move(to: openBurstTransform, relativeTo: anchor, duration: 0.2, timingFunction: .easeOut)
        try? await Task.sleep(for: .seconds(0.3))

        var splitTopTransform = pokeball.transform
        splitTopTransform.translation.y += 0.02
        splitTopTransform.scale = SIMD3<Float>(repeating: 0.004)
        pokeball.move(to: splitTopTransform, relativeTo: anchor, duration: 0.4, timingFunction: .easeOut)

        try? await Task.sleep(for: .seconds(0.2))

        if creature.bundledModelName != nil {
            let creatureEntity = await loadCreatureModel(for: creature)
            creatureEntity.scale = SIMD3<Float>(repeating: 0.0001)
            creatureEntity.position = SIMD3<Float>(0, 0.005, 0)
            anchor.addChild(creatureEntity)

            let targetScale: Float = 0.0004
            var creatureTarget = creatureEntity.transform
            creatureTarget.scale = SIMD3<Float>(repeating: targetScale)
            creatureTarget.translation = SIMD3<Float>(0, 0.005, 0)
            creatureEntity.move(to: creatureTarget, relativeTo: anchor, duration: 0.8, timingFunction: .easeOut)

            let burstParticles = createEnergyBurst(
                at: SIMD3<Float>(0, 0.02, 0),
                color: creature.element.primaryColor,
                secondaryColor: creature.element.secondaryColor
            )
            for particle in burstParticles {
                anchor.addChild(particle)
            }

            try? await Task.sleep(for: .seconds(0.8))

            for animation in creatureEntity.availableAnimations {
                creatureEntity.playAnimation(animation.repeat())
            }

            onCreatureReady(creatureEntity)

            try? await Task.sleep(for: .seconds(0.5))

            var pokeballFade = pokeball.transform
            pokeballFade.scale = SIMD3<Float>(repeating: 0.0001)
            pokeballFade.translation.y = 0.04
            pokeball.move(to: pokeballFade, relativeTo: anchor, duration: 0.5, timingFunction: .easeIn)

            try? await Task.sleep(for: .seconds(1.5))
            for particle in flashParticles + burstParticles {
                particle.removeFromParent()
            }
            pokeball.removeFromParent()
        } else {
            let creatureEntity = CreatureBuilder.buildCreature(for: creature)
            creatureEntity.position.y = 0.01
            anchor.addChild(creatureEntity)
            CreatureBuilder.animateSpawn(entity: creatureEntity)

            onCreatureReady(creatureEntity)

            try? await Task.sleep(for: .seconds(0.5))

            var pokeballFade = pokeball.transform
            pokeballFade.scale = SIMD3<Float>(repeating: 0.0001)
            pokeballFade.translation.y = 0.04
            pokeball.move(to: pokeballFade, relativeTo: anchor, duration: 0.5, timingFunction: .easeIn)

            try? await Task.sleep(for: .seconds(1.5))
            for particle in flashParticles {
                particle.removeFromParent()
            }
            pokeball.removeFromParent()
        }
    }

    private static func loadCreatureModel(for creature: Creature) async -> Entity {
        guard let modelName = creature.bundledModelName else {
            return CreatureBuilder.buildCreature(for: creature)
        }

        let names = [modelName, modelName.replacingOccurrences(of: "_", with: "")]
        for name in names {
            if let url = Bundle.main.url(forResource: name, withExtension: "usdz") {
                do {
                    return try await Entity(contentsOf: url)
                } catch {
                    continue
                }
            }
        }

        return CreatureBuilder.buildCreature(for: creature)
    }

    private static func createOpenFlash(at position: SIMD3<Float>) -> [Entity] {
        var particles: [Entity] = []
        let white = SimpleMaterial(color: .white, roughness: 0.0, isMetallic: true)
        let yellow = SimpleMaterial(color: UIColor(red: 1, green: 0.95, blue: 0.7, alpha: 1), roughness: 0.0, isMetallic: true)

        for i in 0..<12 {
            let angle = Float(i) / 12.0 * .pi * 2
            let material = i % 2 == 0 ? white : yellow
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
            materials: [white]
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
        let primaryMat = SimpleMaterial(color: color, roughness: 0.0, isMetallic: true)
        let secondaryMat = SimpleMaterial(color: secondaryColor, roughness: 0.0, isMetallic: true)

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
