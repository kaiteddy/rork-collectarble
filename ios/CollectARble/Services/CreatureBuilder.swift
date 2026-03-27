import RealityKit
import UIKit

struct CreatureBuilder {
    static func buildCreature(for creature: Creature) -> Entity {
        return buildProceduralCreature(for: creature)
    }

    private static func buildProceduralCreature(for creature: Creature) -> Entity {
        let root = Entity()
        root.name = creature.id

        switch creature.element {
        case .fire:
            buildFireCreature(root: root, creature: creature)
        case .ice:
            buildIceCreature(root: root, creature: creature)
        case .nature:
            buildNatureCreature(root: root, creature: creature)
        case .sports:
            buildSportsCreature(root: root, creature: creature)
        }

        root.scale = SIMD3<Float>(repeating: 0.001)
        return root
    }

    static func animateSpawn(entity: Entity) {
        var target = entity.transform
        target.scale = SIMD3<Float>(repeating: 1.0)
        entity.move(to: target, relativeTo: entity.parent, duration: 0.6, timingFunction: .easeOut)
    }

    static func startIdleAnimation(entity: Entity) {
        let floatUp = Transform(
            scale: entity.transform.scale,
            rotation: simd_quatf(angle: .pi * 2, axis: SIMD3<Float>(0, 1, 0)),
            translation: entity.transform.translation + SIMD3<Float>(0, 0.02, 0)
        )
        entity.move(to: floatUp, relativeTo: entity.parent, duration: 3.0, timingFunction: .easeInOut)
    }

    private static func buildFireCreature(root: Entity, creature: Creature) {
        let bodyMaterial = SimpleMaterial(color: creature.element.primaryColor, roughness: 0.2, isMetallic: true)
        let glowMaterial = SimpleMaterial(color: creature.element.secondaryColor, roughness: 0.1, isMetallic: true)

        let body = ModelEntity(
            mesh: .generateSphere(radius: 0.04),
            materials: [bodyMaterial]
        )
        body.position = SIMD3<Float>(0, 0.06, 0)

        let core = ModelEntity(
            mesh: .generateSphere(radius: 0.025),
            materials: [glowMaterial]
        )
        core.position = SIMD3<Float>(0, 0.06, 0)

        let hornLeft = ModelEntity(
            mesh: .generateCone(height: 0.035, radius: 0.006),
            materials: [bodyMaterial]
        )
        hornLeft.position = SIMD3<Float>(-0.02, 0.1, 0)
        hornLeft.orientation = simd_quatf(angle: 0.3, axis: SIMD3<Float>(0, 0, 1))

        let hornRight = ModelEntity(
            mesh: .generateCone(height: 0.035, radius: 0.006),
            materials: [bodyMaterial]
        )
        hornRight.position = SIMD3<Float>(0.02, 0.1, 0)
        hornRight.orientation = simd_quatf(angle: -0.3, axis: SIMD3<Float>(0, 0, 1))

        let base = ModelEntity(
            mesh: .generateCylinder(height: 0.01, radius: 0.05),
            materials: [SimpleMaterial(color: .darkGray, roughness: 0.8, isMetallic: false)]
        )

        root.addChild(base)
        root.addChild(body)
        root.addChild(core)
        root.addChild(hornLeft)
        root.addChild(hornRight)
    }

    private static func buildIceCreature(root: Entity, creature: Creature) {
        let bodyMaterial = SimpleMaterial(color: creature.element.primaryColor, roughness: 0.05, isMetallic: true)
        let crystalMaterial = SimpleMaterial(color: creature.element.secondaryColor, roughness: 0.0, isMetallic: true)

        let body = ModelEntity(
            mesh: .generateBox(size: SIMD3<Float>(0.05, 0.07, 0.05), cornerRadius: 0.008),
            materials: [bodyMaterial]
        )
        body.position = SIMD3<Float>(0, 0.055, 0)

        let crystal1 = ModelEntity(
            mesh: .generateCone(height: 0.04, radius: 0.01),
            materials: [crystalMaterial]
        )
        crystal1.position = SIMD3<Float>(0, 0.1, 0)

        let crystal2 = ModelEntity(
            mesh: .generateCone(height: 0.025, radius: 0.007),
            materials: [crystalMaterial]
        )
        crystal2.position = SIMD3<Float>(-0.025, 0.08, 0)
        crystal2.orientation = simd_quatf(angle: 0.4, axis: SIMD3<Float>(0, 0, 1))

        let crystal3 = ModelEntity(
            mesh: .generateCone(height: 0.025, radius: 0.007),
            materials: [crystalMaterial]
        )
        crystal3.position = SIMD3<Float>(0.025, 0.08, 0)
        crystal3.orientation = simd_quatf(angle: -0.4, axis: SIMD3<Float>(0, 0, 1))

        let base = ModelEntity(
            mesh: .generateCylinder(height: 0.01, radius: 0.05),
            materials: [SimpleMaterial(color: .darkGray, roughness: 0.8, isMetallic: false)]
        )

        root.addChild(base)
        root.addChild(body)
        root.addChild(crystal1)
        root.addChild(crystal2)
        root.addChild(crystal3)
    }

    private static func buildNatureCreature(root: Entity, creature: Creature) {
        let bodyMaterial = SimpleMaterial(color: creature.element.primaryColor, roughness: 0.6, isMetallic: false)
        let leafMaterial = SimpleMaterial(color: creature.element.secondaryColor, roughness: 0.4, isMetallic: false)

        let trunk = ModelEntity(
            mesh: .generateCylinder(height: 0.06, radius: 0.015),
            materials: [SimpleMaterial(color: UIColor(red: 0.45, green: 0.3, blue: 0.15, alpha: 1), roughness: 0.9, isMetallic: false)]
        )
        trunk.position = SIMD3<Float>(0, 0.04, 0)

        let canopy = ModelEntity(
            mesh: .generateSphere(radius: 0.04),
            materials: [bodyMaterial]
        )
        canopy.position = SIMD3<Float>(0, 0.09, 0)

        let leaf1 = ModelEntity(
            mesh: .generatePlane(width: 0.03, depth: 0.015),
            materials: [leafMaterial]
        )
        leaf1.position = SIMD3<Float>(0.04, 0.07, 0)
        leaf1.orientation = simd_quatf(angle: -0.5, axis: SIMD3<Float>(0, 0, 1))

        let leaf2 = ModelEntity(
            mesh: .generatePlane(width: 0.03, depth: 0.015),
            materials: [leafMaterial]
        )
        leaf2.position = SIMD3<Float>(-0.04, 0.07, 0)
        leaf2.orientation = simd_quatf(angle: 0.5, axis: SIMD3<Float>(0, 0, 1))

        let base = ModelEntity(
            mesh: .generateCylinder(height: 0.01, radius: 0.05),
            materials: [SimpleMaterial(color: .darkGray, roughness: 0.8, isMetallic: false)]
        )

        root.addChild(base)
        root.addChild(trunk)
        root.addChild(canopy)
        root.addChild(leaf1)
        root.addChild(leaf2)
    }

    private static func buildSportsCreature(root: Entity, creature: Creature) {
        let bodyMaterial = SimpleMaterial(color: creature.element.primaryColor, roughness: 0.3, isMetallic: false)
        let accentMaterial = SimpleMaterial(color: creature.element.secondaryColor, roughness: 0.2, isMetallic: true)

        // Body (torso) - use cylinder instead of capsule
        let body = ModelEntity(
            mesh: .generateCylinder(height: 0.06, radius: 0.02),
            materials: [bodyMaterial]
        )
        body.position = SIMD3<Float>(0, 0.07, 0)

        // Head
        let head = ModelEntity(
            mesh: .generateSphere(radius: 0.018),
            materials: [SimpleMaterial(color: UIColor(red: 0.9, green: 0.75, blue: 0.6, alpha: 1), roughness: 0.5, isMetallic: false)]
        )
        head.position = SIMD3<Float>(0, 0.115, 0)

        // Hair
        let hair = ModelEntity(
            mesh: .generateSphere(radius: 0.015),
            materials: [SimpleMaterial(color: UIColor(red: 0.2, green: 0.15, blue: 0.1, alpha: 1), roughness: 0.8, isMetallic: false)]
        )
        hair.position = SIMD3<Float>(0, 0.125, 0)

        // Soccer ball
        let ball = ModelEntity(
            mesh: .generateSphere(radius: 0.012),
            materials: [SimpleMaterial(color: .white, roughness: 0.3, isMetallic: false)]
        )
        ball.position = SIMD3<Float>(0.03, 0.02, 0)

        // Trophy (golden)
        let trophy = ModelEntity(
            mesh: .generateCylinder(height: 0.025, radius: 0.008),
            materials: [accentMaterial]
        )
        trophy.position = SIMD3<Float>(-0.03, 0.04, 0)

        let trophyCup = ModelEntity(
            mesh: .generateSphere(radius: 0.01),
            materials: [accentMaterial]
        )
        trophyCup.position = SIMD3<Float>(-0.03, 0.055, 0)

        let base = ModelEntity(
            mesh: .generateCylinder(height: 0.01, radius: 0.05),
            materials: [SimpleMaterial(color: UIColor(red: 0.1, green: 0.5, blue: 0.1, alpha: 1), roughness: 0.8, isMetallic: false)]
        )

        root.addChild(base)
        root.addChild(body)
        root.addChild(head)
        root.addChild(hair)
        root.addChild(ball)
        root.addChild(trophy)
        root.addChild(trophyCup)
    }
}
