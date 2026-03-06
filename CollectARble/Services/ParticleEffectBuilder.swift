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
            let radius: Float = 0.002 + Float.random(in: 0...0.003)

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
            particle.position = position + SIMD3<Float>(0, 0.03, 0)

            let spread = Float.random(in: 0.05...0.1)
            let height = Float.random(in: 0.01...0.06)
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

    static func createFlamethrowerEffect(at position: SIMD3<Float>, parentAnchor: Entity) -> [Entity] {
        var particles: [Entity] = []

        let fireColors: [UIColor] = [
            UIColor(red: 1.0, green: 0.1, blue: 0.0, alpha: 1.0),
            UIColor(red: 1.0, green: 0.4, blue: 0.0, alpha: 1.0),
            UIColor(red: 1.0, green: 0.6, blue: 0.1, alpha: 1.0),
            UIColor(red: 1.0, green: 0.8, blue: 0.2, alpha: 1.0),
            UIColor(red: 1.0, green: 0.95, blue: 0.5, alpha: 1.0),
        ]

        let waveCount = 5
        let particlesPerWave = 8

        for wave in 0..<waveCount {
            let waveDelay = Double(wave) * 0.15

            for i in 0..<particlesPerWave {
                let angle = Float(i) / Float(particlesPerWave) * .pi * 2
                let spreadAngle = Float.random(in: -0.4...0.4)

                let baseDirection = SIMD3<Float>(0, 0, 1)
                let spread = Float.random(in: 0.005...0.015)
                let offset = SIMD3<Float>(
                    cos(angle) * spread,
                    sin(angle) * spread + Float.random(in: 0.005...0.02),
                    0
                )

                let colorIndex = min(wave, fireColors.count - 1)
                let color = fireColors[colorIndex]
                let size = Float.random(in: 0.002...0.006) * (1.0 - Float(wave) * 0.1)

                let material = SimpleMaterial(color: color, roughness: 0.0, isMetallic: true)
                let particle = ModelEntity(
                    mesh: .generateSphere(radius: size),
                    materials: [material]
                )

                let startPos = position + SIMD3<Float>(0, 0.02, 0) + offset * 0.3
                particle.position = startPos
                particle.scale = SIMD3<Float>(repeating: 0.5)
                parentAnchor.addChild(particle)

                let distance = Float.random(in: 0.06...0.12)
                let endPos = startPos + SIMD3<Float>(
                    sin(spreadAngle) * distance * 0.3,
                    Float.random(in: 0.01...0.04),
                    cos(spreadAngle) * distance
                )

                var midTransform = particle.transform
                midTransform.translation = endPos
                midTransform.scale = SIMD3<Float>(repeating: Float.random(in: 1.2...2.0))

                let duration = Double.random(in: 0.3...0.5) + waveDelay
                particle.move(to: midTransform, relativeTo: parentAnchor, duration: duration, timingFunction: .easeOut)

                particles.append(particle)
            }
        }

        for i in 0..<6 {
            let emberSize = Float.random(in: 0.001...0.003)
            let material = SimpleMaterial(
                color: UIColor(red: 1.0, green: CGFloat.random(in: 0.3...0.8), blue: 0.0, alpha: 1.0),
                roughness: 0.0,
                isMetallic: true
            )
            let ember = ModelEntity(
                mesh: .generateSphere(radius: emberSize),
                materials: [material]
            )

            let startPos = position + SIMD3<Float>(
                Float.random(in: -0.02...0.02),
                Float.random(in: 0.02...0.04),
                Float.random(in: 0.03...0.06)
            )
            ember.position = startPos
            parentAnchor.addChild(ember)

            var target = ember.transform
            target.translation = startPos + SIMD3<Float>(
                Float.random(in: -0.03...0.03),
                Float.random(in: 0.03...0.08),
                Float.random(in: -0.02...0.02)
            )
            target.scale = SIMD3<Float>(repeating: 0.1)

            let duration = Double.random(in: 0.6...1.2)
            ember.move(to: target, relativeTo: parentAnchor, duration: duration, timingFunction: .easeOut)

            particles.append(ember)
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
