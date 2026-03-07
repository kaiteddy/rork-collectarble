import RealityKit
import ARKit
import simd

struct PokeballThrowService {

    // MARK: - Floor Detection

    /// Comprehensive floor detection using multiple raycast strategies
    static func findFloorLevel(arView: ARView, cameraTransform: simd_float4x4) -> Float {
        let cameraY = cameraTransform.columns.3.y

        // Strategy 1: Scan multiple screen points for existing planes
        var detectedFloors: [Float] = []

        // Create a grid of scan points, focusing on the lower half of the screen
        let scanPoints: [CGPoint] = [
            // Center area
            CGPoint(x: arView.bounds.midX, y: arView.bounds.midY),
            CGPoint(x: arView.bounds.midX, y: arView.bounds.midY * 1.3),
            CGPoint(x: arView.bounds.midX, y: arView.bounds.midY * 1.5),

            // Lower section (most likely to hit floor)
            CGPoint(x: arView.bounds.midX, y: arView.bounds.maxY * 0.65),
            CGPoint(x: arView.bounds.midX, y: arView.bounds.maxY * 0.75),
            CGPoint(x: arView.bounds.midX, y: arView.bounds.maxY * 0.85),

            // Left and right lower areas
            CGPoint(x: arView.bounds.midX * 0.5, y: arView.bounds.maxY * 0.7),
            CGPoint(x: arView.bounds.midX * 1.5, y: arView.bounds.maxY * 0.7),
            CGPoint(x: arView.bounds.midX * 0.3, y: arView.bounds.maxY * 0.75),
            CGPoint(x: arView.bounds.midX * 1.7, y: arView.bounds.maxY * 0.75),
        ]

        for point in scanPoints {
            // Try existing plane geometry (most accurate)
            if let hit = arView.raycast(from: point, allowing: .existingPlaneGeometry, alignment: .horizontal).first {
                let y = hit.worldTransform.columns.3.y
                // Only accept floors that are below camera level
                if y < cameraY - 0.3 {
                    detectedFloors.append(y)
                }
            }

            // Try existing planes with infinite extension
            if let hit = arView.raycast(from: point, allowing: .existingPlaneInfinite, alignment: .horizontal).first {
                let y = hit.worldTransform.columns.3.y
                if y < cameraY - 0.3 {
                    detectedFloors.append(y)
                }
            }
        }

        // Strategy 2: Check AR anchors for horizontal planes
        // Access anchors inline to avoid retaining ARFrame
        for anchor in arView.session.currentFrame?.anchors ?? [] {
            if let planeAnchor = anchor as? ARPlaneAnchor,
               planeAnchor.alignment == .horizontal {
                let planeY = planeAnchor.transform.columns.3.y
                // Accept horizontal planes below camera
                if planeY < cameraY - 0.3 {
                    detectedFloors.append(planeY)
                    print("DEBUG: Found plane anchor at y=\(planeY)")
                }
            }
        }

        // Strategy 3: If we have detections, use the most common floor level
        if !detectedFloors.isEmpty {
            // Sort and find the most common value (cluster around similar Y values)
            let sorted = detectedFloors.sorted()

            // Group similar values (within 5cm of each other)
            var groups: [[Float]] = []
            var currentGroup: [Float] = [sorted[0]]

            for i in 1..<sorted.count {
                if abs(sorted[i] - sorted[i-1]) < 0.05 {
                    currentGroup.append(sorted[i])
                } else {
                    groups.append(currentGroup)
                    currentGroup = [sorted[i]]
                }
            }
            groups.append(currentGroup)

            // Find the largest group (most detections at similar height)
            let bestGroup = groups.max(by: { $0.count < $1.count }) ?? groups[0]
            let floorY = bestGroup.reduce(0, +) / Float(bestGroup.count)

            print("DEBUG: Floor detection - \(detectedFloors.count) hits, using y=\(floorY) from cluster of \(bestGroup.count)")
            return floorY
        }

        // Fallback: Estimate floor based on typical phone holding height
        let estimatedFloor = cameraY - 1.2
        print("DEBUG: No floor detected, estimating at y=\(estimatedFloor)")
        return estimatedFloor
    }

    /// Real-time floor check along the trajectory path
    static func findFloorAtPosition(arView: ARView, worldX: Float, worldZ: Float, cameraY: Float) -> Float? {
        // Convert world position to screen point
        let worldPos = SIMD3<Float>(worldX, cameraY - 0.5, worldZ)
        let screenPoint = arView.project(worldPos)

        guard let point = screenPoint, arView.bounds.contains(point) else {
            return nil
        }

        // Raycast down from that screen point
        if let hit = arView.raycast(from: point, allowing: .existingPlaneGeometry, alignment: .horizontal).first {
            return hit.worldTransform.columns.3.y
        }

        if let hit = arView.raycast(from: point, allowing: .existingPlaneInfinite, alignment: .horizontal).first {
            return hit.worldTransform.columns.3.y
        }

        return nil
    }

    // MARK: - Trajectory Calculation

    /// Calculate throw trajectory based on flick velocity
    static func calculateThrowTrajectory(
        startPosition: SIMD3<Float>,
        velocity: SIMD2<Float>,
        cameraTransform: simd_float4x4,
        targetY: Float
    ) -> ThrowTrajectory {
        // Convert 2D screen velocity to 3D throw parameters
        let speed = sqrt(velocity.x * velocity.x + velocity.y * velocity.y)
        let normalizedSpeed = min(max(speed / 1000.0, 0.3), 1.0) // Gentler scaling

        // Get camera vectors
        let cameraForward = -simd_normalize(SIMD3<Float>(
            cameraTransform.columns.2.x,
            0, // Ignore vertical component for forward direction
            cameraTransform.columns.2.z
        ))
        let cameraRight = simd_normalize(SIMD3<Float>(
            cameraTransform.columns.0.x,
            0,
            cameraTransform.columns.0.z
        ))

        // Horizontal direction based on swipe (reduced sensitivity)
        let horizontalBias = velocity.x / 1000.0
        var throwDirection = simd_normalize(cameraForward + cameraRight * horizontalBias)

        // Calculate throw arc - gentle upward component for a nice arc
        let upwardAngle: Float = 0.25 // Lower arc
        throwDirection = SIMD3<Float>(
            throwDirection.x,
            upwardAngle,
            throwDirection.z
        )
        throwDirection = simd_normalize(throwDirection)

        // Throw speed - reduced for closer landing (about 1-2 meters in front)
        let throwSpeed: Float = 1.2 * normalizedSpeed + 1.0

        print("DEBUG: Throw - speed=\(throwSpeed), targetY=\(targetY), startY=\(startPosition.y)")

        return ThrowTrajectory(
            startPosition: startPosition,
            initialVelocity: throwDirection * throwSpeed,
            gravity: SIMD3<Float>(0, -6.0, 0),  // Slightly less gravity for smoother arc
            targetY: targetY
        )
    }

    // MARK: - Animation

    /// Animate ball along trajectory with realistic landing
    static func animateThrow(
        ball: Entity,
        trajectory: ThrowTrajectory,
        arView: ARView,
        onLand: @escaping (SIMD3<Float>) -> Void
    ) {
        let startTime = Date()
        let maxDuration: TimeInterval = 4.0
        var spinAngle: Float = 0
        let targetY = trajectory.targetY
        var hasLanded = false

        print("DEBUG: Starting throw - targetY=\(targetY), start=\(trajectory.startPosition)")

        Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { timer in
            guard !hasLanded else { return }

            let elapsed = Float(Date().timeIntervalSince(startTime))
            let position = trajectory.positionAt(time: elapsed)

            // Real-time floor check at current XZ position
            var currentFloorY = targetY
            if let detectedFloor = findFloorAtPosition(
                arView: arView,
                worldX: position.x,
                worldZ: position.z,
                cameraY: trajectory.startPosition.y
            ) {
                currentFloorY = detectedFloor
            }

            // Check if ball has reached the floor
            let landingThreshold = currentFloorY + 0.015  // Small offset for ball radius
            if position.y <= landingThreshold {
                hasLanded = true
                timer.invalidate()

                let landPosition = SIMD3<Float>(position.x, currentFloorY, position.z)
                print("DEBUG: Ball landed at \(landPosition)")

                // Get camera position for final facing direction
                let cameraPos = SIMD3<Float>(
                    arView.cameraTransform.matrix.columns.3.x,
                    arView.cameraTransform.matrix.columns.3.y,
                    arView.cameraTransform.matrix.columns.3.z
                )

                // Perform bounce animation before callback
                performLandingBounce(ball: ball, landPosition: landPosition, floorY: currentFloorY, cameraPosition: cameraPos) {
                    onLand(landPosition)
                }
                return
            }

            // Timeout safety
            if elapsed > Float(maxDuration) {
                hasLanded = true
                timer.invalidate()
                let landPosition = SIMD3<Float>(position.x, targetY, position.z)
                print("DEBUG: Throw timed out")
                onLand(landPosition)
                return
            }

            // Update position
            ball.position = position

            // Spin the ball
            spinAngle += 0.25
            ball.orientation = simd_quatf(angle: spinAngle, axis: SIMD3<Float>(1, 0.2, 0))
        }
    }

    /// Perform realistic landing bounce
    private static func performLandingBounce(
        ball: Entity,
        landPosition: SIMD3<Float>,
        floorY: Float,
        cameraPosition: SIMD3<Float>,
        completion: @escaping () -> Void
    ) {
        // Place ball at land position
        ball.position = landPosition

        // Calculate final facing angle (facing the camera)
        let directionToCamera = SIMD3<Float>(
            cameraPosition.x - landPosition.x,
            0,  // Ignore Y for horizontal facing
            cameraPosition.z - landPosition.z
        )
        let facingAngle = atan2(directionToCamera.x, directionToCamera.z) + .pi

        // Series of diminishing bounces
        let bounceHeights: [Float] = [0.04, 0.015, 0.005]
        let bounceDurations: [Double] = [0.2, 0.12, 0.08]

        Task {
            for (index, height) in bounceHeights.enumerated() {
                // Bounce up with slight random wobble
                var bounceUp = ball.transform
                bounceUp.translation = SIMD3<Float>(landPosition.x, floorY + height, landPosition.z)
                bounceUp.rotation = simd_quatf(angle: facingAngle + Float.random(in: -0.2...0.2), axis: SIMD3<Float>(0, 1, 0))
                ball.move(to: bounceUp, relativeTo: nil, duration: bounceDurations[index], timingFunction: .easeOut)

                try? await Task.sleep(for: .seconds(bounceDurations[index]))

                // Bounce down
                var bounceDown = ball.transform
                bounceDown.translation = SIMD3<Float>(landPosition.x, floorY + 0.01, landPosition.z)
                ball.move(to: bounceDown, relativeTo: nil, duration: bounceDurations[index] * 0.7, timingFunction: .easeIn)

                try? await Task.sleep(for: .seconds(bounceDurations[index] * 0.7))
            }

            // Final settle - face the camera
            var finalPos = ball.transform
            finalPos.translation = SIMD3<Float>(landPosition.x, floorY + 0.01, landPosition.z)
            finalPos.rotation = simd_quatf(angle: facingAngle, axis: SIMD3<Float>(0, 1, 0))
            ball.move(to: finalPos, relativeTo: nil, duration: 0.1, timingFunction: .easeOut)

            try? await Task.sleep(for: .seconds(0.15))

            await MainActor.run {
                completion()
            }
        }
    }

    // MARK: - Ball Creation

    /// Create a throwable ball at the camera position
    static func createThrowableBall(for creature: Creature, at cameraTransform: simd_float4x4) async -> Entity? {
        let ballType = SpawnBallService.ballType(for: creature)

        guard let ball = await SpawnBallService.loadBall(type: ballType) else {
            return nil
        }

        // Position in front of and slightly below camera
        let cameraPosition = SIMD3<Float>(
            cameraTransform.columns.3.x,
            cameraTransform.columns.3.y,
            cameraTransform.columns.3.z
        )
        let cameraForward = -simd_normalize(SIMD3<Float>(
            cameraTransform.columns.2.x,
            cameraTransform.columns.2.y,
            cameraTransform.columns.2.z
        ))

        ball.position = cameraPosition + cameraForward * 0.25 + SIMD3<Float>(0, -0.02, 0)
        ball.scale = SIMD3<Float>(repeating: ballType.throwScale)

        // Orient ball to face the user (rotate 180 degrees around Y axis from camera forward)
        let horizontalForward = simd_normalize(SIMD3<Float>(cameraForward.x, 0, cameraForward.z))
        let angle = atan2(horizontalForward.x, horizontalForward.z)
        ball.orientation = simd_quatf(angle: angle + .pi, axis: SIMD3<Float>(0, 1, 0))

        print("DEBUG: Created \(ballType) at \(ball.position)")
        return ball
    }

    /// Update ball position to follow camera
    static func updateBallPosition(ball: Entity, cameraTransform: simd_float4x4) {
        let cameraPosition = SIMD3<Float>(
            cameraTransform.columns.3.x,
            cameraTransform.columns.3.y,
            cameraTransform.columns.3.z
        )
        let cameraForward = -simd_normalize(SIMD3<Float>(
            cameraTransform.columns.2.x,
            cameraTransform.columns.2.y,
            cameraTransform.columns.2.z
        ))

        ball.position = cameraPosition + cameraForward * 0.25 + SIMD3<Float>(0, -0.02, 0)

        // Keep ball oriented facing the user
        let horizontalForward = simd_normalize(SIMD3<Float>(cameraForward.x, 0, cameraForward.z))
        let angle = atan2(horizontalForward.x, horizontalForward.z)
        ball.orientation = simd_quatf(angle: angle + .pi, axis: SIMD3<Float>(0, 1, 0))
    }

    // Legacy compatibility
    static func createThrowablePokeball(at cameraTransform: simd_float4x4) async -> Entity? {
        guard let pokeball = await PokeballAnimationService.loadPokeball() else {
            return nil
        }

        let cameraPosition = SIMD3<Float>(
            cameraTransform.columns.3.x,
            cameraTransform.columns.3.y,
            cameraTransform.columns.3.z
        )
        let cameraForward = -simd_normalize(SIMD3<Float>(
            cameraTransform.columns.2.x,
            cameraTransform.columns.2.y,
            cameraTransform.columns.2.z
        ))

        pokeball.position = cameraPosition + cameraForward * 0.25 + SIMD3<Float>(0, -0.02, 0)
        pokeball.scale = SIMD3<Float>(repeating: 0.0003)

        // Orient pokeball to face the user
        let horizontalForward = simd_normalize(SIMD3<Float>(cameraForward.x, 0, cameraForward.z))
        let angle = atan2(horizontalForward.x, horizontalForward.z)
        pokeball.orientation = simd_quatf(angle: angle + .pi, axis: SIMD3<Float>(0, 1, 0))

        return pokeball
    }

    static func updatePokeballPosition(pokeball: Entity, cameraTransform: simd_float4x4) {
        updateBallPosition(ball: pokeball, cameraTransform: cameraTransform)
    }
}

// MARK: - Trajectory

struct ThrowTrajectory {
    let startPosition: SIMD3<Float>
    let initialVelocity: SIMD3<Float>
    let gravity: SIMD3<Float>
    let targetY: Float

    /// Calculate position at time t using physics: p = p0 + v0*t + 0.5*g*t^2
    func positionAt(time t: Float) -> SIMD3<Float> {
        return startPosition + initialVelocity * t + 0.5 * gravity * t * t
    }

    /// Calculate velocity at time t: v = v0 + g*t
    func velocityAt(time t: Float) -> SIMD3<Float> {
        return initialVelocity + gravity * t
    }

    /// Estimate time to reach target Y level
    func timeToReachY(_ y: Float) -> Float? {
        // Solve: y = startY + vy*t + 0.5*g*t^2
        // 0.5*g*t^2 + vy*t + (startY - y) = 0
        let a = 0.5 * gravity.y
        let b = initialVelocity.y
        let c = startPosition.y - y

        let discriminant = b*b - 4*a*c
        if discriminant < 0 { return nil }

        let t1 = (-b + sqrt(discriminant)) / (2*a)
        let t2 = (-b - sqrt(discriminant)) / (2*a)

        // Return the positive time (future)
        if t1 > 0 && t2 > 0 { return min(t1, t2) }
        if t1 > 0 { return t1 }
        if t2 > 0 { return t2 }
        return nil
    }
}
