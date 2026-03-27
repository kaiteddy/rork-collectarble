import RealityKit
import UIKit

struct ParticleEffectBuilder {
    static func createAttackParticles(for creature: Creature, at position: SIMD3<Float>) -> [Entity] {
        var particles: [Entity] = []
        let color = creature.element.primaryColor
        let secondaryColor = creature.element.secondaryColor

        // Inner burst - fast, tight ring
        let innerCount = 16
        for i in 0..<innerCount {
            let angle = Float(i) / Float(innerCount) * .pi * 2
            let radius: Float = 0.003 + Float.random(in: 0...0.003)

            // Non-metallic for soft glow effect
            var material = SimpleMaterial()
            let particleColor = i % 2 == 0 ? color : secondaryColor
            material.color = .init(tint: particleColor.withAlphaComponent(0.9))
            material.metallic = .init(floatLiteral: 0.0)
            material.roughness = .init(floatLiteral: 0.5)

            let particle = ModelEntity(mesh: .generateSphere(radius: radius), materials: [material])
            particle.position = position + SIMD3<Float>(0, 0.06, 0)

            let spread = Float.random(in: 0.06...0.10)
            let height = Float.random(in: 0.03...0.08)

            var target = particle.transform
            target.translation = position + SIMD3<Float>(cos(angle) * spread, height, sin(angle) * spread)
            target.scale = SIMD3<Float>(repeating: 0.01)
            particle.move(to: target, relativeTo: nil, duration: Double.random(in: 0.25...0.5), timingFunction: .easeOut)
            particles.append(particle)
        }

        // Outer burst - slower, wider ring
        let outerCount = 20
        for i in 0..<outerCount {
            let angle = Float(i) / Float(outerCount) * .pi * 2 + 0.1
            let radius: Float = 0.002 + Float.random(in: 0...0.005)

            // Non-metallic for soft glow effect
            var material = SimpleMaterial()
            let particleColor: UIColor = i % 3 == 0 ? .white : color
            material.color = .init(tint: particleColor.withAlphaComponent(0.9))
            material.metallic = .init(floatLiteral: 0.0)
            material.roughness = .init(floatLiteral: 0.5)

            let particle = ModelEntity(mesh: .generateSphere(radius: radius), materials: [material])
            particle.position = position + SIMD3<Float>(0, 0.06, 0)

            let spread = Float.random(in: 0.12...0.20)
            let height = Float.random(in: 0.01...0.12)

            var target = particle.transform
            target.translation = position + SIMD3<Float>(cos(angle) * spread, height, sin(angle) * spread)
            target.scale = SIMD3<Float>(repeating: 0.005)
            particle.move(to: target, relativeTo: nil, duration: Double.random(in: 0.5...0.9), timingFunction: .easeOut)
            particles.append(particle)
        }

        // Central energy orb that expands and fades
        var orbMaterial = SimpleMaterial()
        orbMaterial.color = .init(tint: secondaryColor.withAlphaComponent(0.7))
        orbMaterial.metallic = .init(floatLiteral: 0.0)
        orbMaterial.roughness = .init(floatLiteral: 0.8)

        let orb = ModelEntity(mesh: .generateSphere(radius: 0.005), materials: [orbMaterial])
        orb.position = position + SIMD3<Float>(0, 0.06, 0)
        var orbTarget = orb.transform
        orbTarget.scale = SIMD3<Float>(repeating: 6.0)  // Slightly smaller
        orb.move(to: orbTarget, relativeTo: nil, duration: 0.5, timingFunction: .easeOut)
        particles.append(orb)

        return particles
    }

    static func removeParticles(_ particles: [Entity], from scene: Entity, delay: Double = 1.0) {
        Task {
            try? await Task.sleep(for: .seconds(delay))
            for particle in particles {
                particle.removeFromParent()
            }
        }
    }
}
