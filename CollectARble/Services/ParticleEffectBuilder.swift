import RealityKit
import UIKit

struct ParticleEffectBuilder {
    static func createAttackParticles(for creature: Creature, at position: SIMD3<Float>) -> [Entity] {
        var particles: [Entity] = []
        let color = creature.element.primaryColor
        let secondaryColor = creature.element.secondaryColor
        let particleCount = 24

        for i in 0..<particleCount {
            let angle = Float(i) / Float(particleCount) * .pi * 2
            let radius: Float = 0.003 + Float.random(in: 0...0.004)

            let material: SimpleMaterial
            if i % 3 == 0 {
                material = SimpleMaterial(color: secondaryColor, roughness: 0.0, isMetallic: true)
            } else {
                material = SimpleMaterial(color: color, roughness: 0.1, isMetallic: true)
            }

            let particle = ModelEntity(
                mesh: .generateSphere(radius: radius),
                materials: [material]
            )
            particle.position = position + SIMD3<Float>(0, 0.06, 0)

            let spread = Float.random(in: 0.08...0.15)
            let height = Float.random(in: 0.02...0.1)
            let targetX = cos(angle) * spread
            let targetZ = sin(angle) * spread

            var targetTransform = particle.transform
            targetTransform.translation = position + SIMD3<Float>(targetX, height, targetZ)
            targetTransform.scale = SIMD3<Float>(repeating: 0.01)

            let duration = Double.random(in: 0.4...0.8)
            particle.move(to: targetTransform, relativeTo: nil, duration: duration, timingFunction: .easeOut)

            particles.append(particle)
        }

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
