import SwiftUI
import RealityKit
import ARKit

struct ARExperienceView: View {
    @Binding var isPresented: Bool
    var initialCreatureId: String = ""
    var startInThrowMode: Bool = false
    @State private var viewModel = ARViewModel()
    @State private var attackTrigger: Int = 0

    private let accentBlue = Color(red: 0.0, green: 0.48, blue: 1.0)

    var body: some View {
        ZStack {
            #if targetEnvironment(simulator)
            ARUnavailablePlaceholder(isPresented: $isPresented)
            #else
            if ARWorldTrackingConfiguration.isSupported {
                arContent
            } else {
                ARUnavailablePlaceholder(isPresented: $isPresented)
            }
            #endif
        }
        .onAppear {
            // Set the selected creature if coming from card collection
            if !initialCreatureId.isEmpty {
                if let index = viewModel.availableCreatures.firstIndex(where: { $0.id == initialCreatureId }) {
                    viewModel.selectedCreatureIndex = index
                }
            }

            // Auto-enter card drop mode if requested (from card selection)
            if startInThrowMode {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    viewModel.enterCardDropMode()
                }
            }
        }
    }

    private var arContent: some View {
        ZStack(alignment: .top) {
            ARViewContainer(viewModel: viewModel)
                .ignoresSafeArea()

            // Attack screen flash
            if viewModel.showAttackFlash {
                (viewModel.currentCreature?.element.displayColor ?? .white)
                    .opacity(0.4)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            topBar

            // Damage number floating up
            if viewModel.showDamageNumber {
                Text("-\(viewModel.lastDamage)")
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .foregroundStyle(.red)
                    .shadow(color: .black, radius: 4, x: 0, y: 2)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.5).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
                    .allowsHitTesting(false)
            }

            VStack {
                Spacer()

                // Speech bubble from character
                if viewModel.showSpeechBubble, let creature = viewModel.currentCreature {
                    ARSpeechBubble(
                        message: viewModel.lastCharacterMessage,
                        creature: creature,
                        isVisible: $viewModel.showSpeechBubble
                    )
                    .padding(.horizontal, 40)
                    .transition(.scale.combined(with: .opacity))
                }

                // HP Bar (shown when creature is spawned)
                if viewModel.isCreatureSpawned {
                    hpBar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                bottomControls
            }
        }
        .animation(.easeOut(duration: 0.15), value: viewModel.showAttackFlash)
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: viewModel.showDamageNumber)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.showSpeechBubble)
        .sheet(isPresented: $viewModel.showChat) {
            if let creature = viewModel.currentCreature {
                CharacterChatView(creature: creature, isPresented: $viewModel.showChat)
                    .presentationDetents([.fraction(0.4), .medium])
                    .presentationDragIndicator(.visible)
                    .presentationBackgroundInteraction(.enabled)
            }
        }
    }

    private var hpBar: some View {
        VStack(spacing: 4) {
            if let creature = viewModel.currentCreature {
                HStack {
                    Image(systemName: creature.element.symbolName)
                        .font(.caption)
                        .foregroundStyle(creature.element.displayColor)
                    Text(creature.name)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                    Spacer()
                    Text("HP \(viewModel.creatureHP)/\(viewModel.creatureMaxHP)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.8))
                }

                GeometryReader { geo in
                    Capsule()
                        .fill(Color.white.opacity(0.15))
                        .frame(height: 8)
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(hpColor)
                                .frame(
                                    width: geo.size.width * CGFloat(viewModel.creatureHP) / CGFloat(max(viewModel.creatureMaxHP, 1)),
                                    height: 8
                                )
                                .animation(.easeOut(duration: 0.4), value: viewModel.creatureHP)
                        }
                }
                .frame(height: 8)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
        .padding(.horizontal, 20)
        .padding(.bottom, 4)
    }

    private var hpColor: Color {
        let ratio = Double(viewModel.creatureHP) / Double(max(viewModel.creatureMaxHP, 1))
        if ratio > 0.5 { return .green }
        if ratio > 0.25 { return .yellow }
        return .red
    }

    private var topBar: some View {
        HStack {
            Button {
                isPresented = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: Circle())
            }

            Spacer()

            if viewModel.isCreatureSpawned {
                Button {
                    viewModel.resetScene()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .animation(.snappy, value: viewModel.isCreatureSpawned)
    }

    private var bottomControls: some View {
        VStack(spacing: 12) {
            Text(viewModel.statusMessage)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
                .animation(.snappy, value: viewModel.statusMessage)

            if !viewModel.isCreatureSpawned && !viewModel.isPokeballAnimating && !viewModel.isCardDropMode {
                creatureSelector
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if viewModel.isCardDetected && !viewModel.isCreatureSpawned && !viewModel.isPokeballAnimating {
                cardDetectionIndicator
                    .transition(.scale.combined(with: .opacity))
            }

            if !viewModel.isCreatureSpawned && !viewModel.isCardDetected && !viewModel.isPokeballAnimating && !viewModel.isThrowMode && !viewModel.isCardDropMode {
                scanHint
                    .transition(.move(edge: .bottom).combined(with: .opacity))

                // Throw button
                throwButton
                    .transition(.scale.combined(with: .opacity))
            }

            if viewModel.isCardDropMode && viewModel.waitingForSurface {
                cardDropHint
                    .transition(.scale.combined(with: .opacity))
            }

            if viewModel.isCardDropMode && viewModel.isCardOnSurface && !viewModel.isThrowMode {
                cardOnSurfaceHint
                    .transition(.scale.combined(with: .opacity))
            }

            if viewModel.isThrowMode {
                throwModeHint
                    .transition(.scale.combined(with: .opacity))
            }

            if viewModel.isPokeballAnimating {
                pokeballHint
                    .transition(.scale.combined(with: .opacity))
            }

            if viewModel.isCreatureSpawned {
                if !viewModel.isTrackingCard {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                        Text("Point camera at card to track")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .transition(.opacity)
                }

                interactionHint
                    .transition(.opacity)

                HStack(spacing: 12) {
                    chatButton
                    attackButton
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.bottom, 40)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: viewModel.isCreatureSpawned)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.isCardDetected)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.isPokeballAnimating)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.isCardDropMode)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.isCardOnSurface)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.waitingForSurface)
    }

    private var interactionHint: some View {
        HStack(spacing: 16) {
            HStack(spacing: 4) {
                Image(systemName: "hand.draw.fill")
                    .font(.caption)
                Text("Drag to rotate")
                    .font(.caption2)
            }

            HStack(spacing: 4) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.caption)
                Text("Pinch to resize")
                    .font(.caption2)
            }
        }
        .foregroundStyle(.white.opacity(0.7))
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private var cardDetectionIndicator: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "creditcard.fill")
                    .font(.title3)
                    .foregroundStyle(.green)
                    .symbolEffect(.pulse, isActive: viewModel.isCardDetected)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Card detected!")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)

                    Text("Hold steady to summon creature...")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }

                Spacer()
            }

            GeometryReader { geo in
                Capsule()
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 6)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(LinearGradient(colors: [.green, .cyan], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * CGFloat(viewModel.cardDetectionProgress), height: 6)
                            .animation(.linear(duration: 0.1), value: viewModel.cardDetectionProgress)
                    }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
        .padding(.horizontal, 20)
    }

    private var scanHint: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "viewfinder")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .symbolEffect(.breathe, isActive: !viewModel.isCreatureSpawned)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Scanning for cards...")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)

                    Text("Point at a card, or tap a flat surface")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private var pokeballHint: some View {
        let creature = viewModel.availableCreatures[viewModel.selectedCreatureIndex]
        let isSports = creature.element == .sports
        let ballName = isSports ? "Football" : "Pokéball"
        let ballColor: Color = isSports ? .blue : .red

        return HStack(spacing: 10) {
            Image(systemName: isSports ? "soccerball" : "circle.fill")
                .font(.title3)
                .foregroundStyle(ballColor)
                .symbolEffect(.pulse, isActive: viewModel.isPokeballAnimating)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(ballName) activated!")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                Text("A creature is emerging...")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private var creatureSelector: some View {
        HStack(spacing: 12) {
            ForEach(Array(viewModel.availableCreatures.enumerated()), id: \.element.id) { index, creature in
                Button {
                    viewModel.selectedCreatureIndex = index
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: creature.element.symbolName)
                            .font(.system(size: 22))
                            .foregroundStyle(creature.element.displayColor)
                            .frame(width: 50, height: 50)
                            .background(
                                viewModel.selectedCreatureIndex == index
                                    ? creature.element.displayColor.opacity(0.2)
                                    : Color.white.opacity(0.1),
                                in: .rect(cornerRadius: 12)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(
                                        viewModel.selectedCreatureIndex == index
                                            ? creature.element.displayColor
                                            : Color.clear,
                                        lineWidth: 2
                                    )
                            )

                        Text(creature.name)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.white)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 20))
    }

    private var attackButton: some View {
        Button {
            attackTrigger += 1
            viewModel.triggerAttack()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill")
                    .font(.title3)
                    .symbolEffect(.bounce, value: attackTrigger)

                if let creature = viewModel.currentCreature {
                    Text(creature.attackName)
                        .font(.subheadline.weight(.semibold))
                }
            }
            .foregroundStyle(.white)
            .frame(height: 50)
            .padding(.horizontal, 20)
            .background(
                viewModel.currentCreature?.element.displayColor ?? accentBlue,
                in: .rect(cornerRadius: 14)
            )
            .opacity(viewModel.isAttacking ? 0.6 : 1.0)
        }
        .disabled(viewModel.isAttacking)
        .sensoryFeedback(.impact(weight: .heavy), trigger: attackTrigger)
    }

    private var chatButton: some View {
        Button {
            viewModel.openChat()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "bubble.left.fill")
                    .font(.title3)
                Text("Chat")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.white)
            .frame(height: 50)
            .padding(.horizontal, 20)
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 14))
        }
    }

    private var throwButton: some View {
        let creature = viewModel.availableCreatures[viewModel.selectedCreatureIndex]
        let isSports = creature.element == .sports
        let ballName = isSports ? "Football" : "Pokeball"
        let ballColor: Color = isSports ? .blue : .red

        return Button {
            viewModel.enterThrowMode()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isSports ? "soccerball" : "circle.fill")
                    .font(.title2)
                    .foregroundStyle(ballColor)
                Text("Throw \(ballName)")
                    .font(.headline)
            }
            .foregroundStyle(.white)
            .frame(height: 56)
            .padding(.horizontal, 24)
            .background(
                LinearGradient(colors: [ballColor, ballColor.opacity(0.7)], startPoint: .top, endPoint: .bottom),
                in: .rect(cornerRadius: 16)
            )
        }
        .padding(.top, 8)
    }

    private var throwModeHint: some View {
        let creature = viewModel.availableCreatures[viewModel.selectedCreatureIndex]
        let isSports = creature.element == .sports
        let ballName = isSports ? "Football" : "Pokeball"
        let ballColor: Color = isSports ? .blue : .red

        return VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: isSports ? "soccerball" : "hand.draw.fill")
                    .font(.title3)
                    .foregroundStyle(ballColor)
                    .symbolEffect(.pulse, isActive: viewModel.isReadyToThrow)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Throw Mode Active")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)

                    Text("Swipe forward to throw the \(ballName)!")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }

                Spacer()

                Button {
                    viewModel.exitThrowMode()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
        .padding(.horizontal, 20)
    }

    private var cardDropHint: some View {
        let creature = viewModel.availableCreatures[viewModel.selectedCreatureIndex]

        return VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "creditcard.fill")
                    .font(.title3)
                    .foregroundStyle(creature.element.displayColor)
                    .symbolEffect(.bounce, isActive: true)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Summoning \(creature.name)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)

                    Text("Tap a flat surface to place the card")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }

                Spacer()

                Button {
                    viewModel.exitCardDropMode()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
        .padding(.horizontal, 20)
    }

    private var cardOnSurfaceHint: some View {
        let creature = viewModel.availableCreatures[viewModel.selectedCreatureIndex]

        return VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundStyle(creature.element.displayColor)
                    .symbolEffect(.variableColor, isActive: true)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(creature.name) Card Ready!")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)

                    Text("Card placed. Preparing to summon...")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }

                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
        .padding(.horizontal, 20)
    }
}

struct ARViewContainer: UIViewRepresentable {
    let viewModel: ARViewModel

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        let coaching = ARCoachingOverlayView()
        coaching.session = arView.session
        coaching.goal = .tracking
        coaching.activatesAutomatically = true
        coaching.translatesAutoresizingMaskIntoConstraints = false
        arView.addSubview(coaching)
        NSLayoutConstraint.activate([
            coaching.topAnchor.constraint(equalTo: arView.topAnchor),
            coaching.bottomAnchor.constraint(equalTo: arView.bottomAnchor),
            coaching.leadingAnchor.constraint(equalTo: arView.leadingAnchor),
            coaching.trailingAnchor.constraint(equalTo: arView.trailingAnchor),
        ])

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        arView.addGestureRecognizer(tap)

        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        pan.maximumNumberOfTouches = 1
        arView.addGestureRecognizer(pan)

        let pinch = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinch(_:)))
        arView.addGestureRecognizer(pinch)

        context.coordinator.arView = arView
        viewModel.setARView(arView)

        arView.session.delegate = context.coordinator

        viewModel.configureSession()

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    class Coordinator: NSObject, ARSessionDelegate {
        let viewModel: ARViewModel
        var arView: ARView?
        private var lastPanLocation: CGPoint = .zero

        init(viewModel: ARViewModel) {
            self.viewModel = viewModel
        }

        @objc func handleTap(_ sender: UITapGestureRecognizer) {
            guard let arView = sender.view as? ARView else { return }
            let location = sender.location(in: arView)
            print("DEBUG: Tap detected at \(location)")

            if viewModel.isCreatureSpawned {
                print("DEBUG: Creature spawned, triggering attack")
                viewModel.triggerAttack()
                return
            }

            guard !viewModel.isPokeballAnimating else {
                print("DEBUG: Pokeball animating, ignoring tap")
                return
            }

            // Handle card drop mode - waiting for surface to place card
            if viewModel.isCardDropMode && viewModel.waitingForSurface {
                print("DEBUG: Card drop mode - looking for surface...")
                let results = arView.raycast(from: location, allowing: .estimatedPlane, alignment: .horizontal)
                if let result = results.first {
                    print("DEBUG: Dropping card at surface")
                    viewModel.dropCardOnSurface(at: result.worldTransform)
                    return
                }

                let fallback = arView.raycast(from: location, allowing: .existingPlaneGeometry, alignment: .horizontal)
                if let result = fallback.first {
                    print("DEBUG: Dropping card at existing plane")
                    viewModel.dropCardOnSurface(at: result.worldTransform)
                    return
                }

                print("DEBUG: No surface found for card drop")
                return
            }

            // Normal spawn mode
            print("DEBUG: Attempting raycast...")
            let results = arView.raycast(from: location, allowing: .estimatedPlane, alignment: .horizontal)
            print("DEBUG: Raycast results (estimated): \(results.count)")
            if let result = results.first {
                print("DEBUG: Spawning at estimated plane")
                viewModel.spawnCreature(at: result.worldTransform)
                return
            }

            let fallback = arView.raycast(from: location, allowing: .existingPlaneGeometry, alignment: .horizontal)
            print("DEBUG: Raycast results (existing): \(fallback.count)")
            if let result = fallback.first {
                print("DEBUG: Spawning at existing plane")
                viewModel.spawnCreature(at: result.worldTransform)
            } else {
                print("DEBUG: No plane detected - point at a flat surface")
            }
        }

        @objc func handlePan(_ sender: UIPanGestureRecognizer) {
            // Handle throw gesture in throw mode
            if viewModel.isThrowMode && viewModel.isReadyToThrow {
                if sender.state == .ended {
                    let velocity = sender.velocity(in: sender.view)
                    let speed = sqrt(velocity.x * velocity.x + velocity.y * velocity.y)
                    print("DEBUG: Pan ended in throw mode, velocity: \(velocity), speed: \(speed)")

                    // Throw if flicking with enough speed (accept any direction, prefer upward)
                    // Speed threshold of 200 is quite low, making it easy to throw
                    if speed > 200 {
                        print("DEBUG: Throw gesture detected - speed \(speed) > 200")
                        // Convert velocity: negative y means upward flick (forward throw)
                        viewModel.handleThrowGesture(velocity: velocity)
                    } else {
                        print("DEBUG: Gesture too slow for throw, speed \(speed) < 200")
                    }
                }
                return
            }

            // Handle rotation when creature is spawned
            guard viewModel.isCreatureSpawned else { return }

            switch sender.state {
            case .began:
                lastPanLocation = sender.location(in: sender.view)
            case .changed:
                let currentLocation = sender.location(in: sender.view)
                let delta = CGPoint(
                    x: currentLocation.x - lastPanLocation.x,
                    y: currentLocation.y - lastPanLocation.y
                )
                viewModel.handlePanGesture(translation: delta)
                lastPanLocation = currentLocation
            default:
                break
            }
        }

        @objc func handlePinch(_ sender: UIPinchGestureRecognizer) {
            print("DEBUG: Pinch gesture state: \(sender.state.rawValue), scale: \(sender.scale)")
            guard viewModel.isCreatureSpawned else {
                print("DEBUG: Creature not spawned, ignoring pinch")
                return
            }

            switch sender.state {
            case .changed:
                viewModel.handlePinchGesture(scale: Float(sender.scale))
            case .ended, .cancelled:
                viewModel.handlePinchEnd(scale: Float(sender.scale))
                sender.scale = 1.0
            default:
                break
            }
        }

        nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
            // Note: processFrame is currently a no-op, but if we need frame data in the future,
            // extract it here before creating the Task to avoid retaining ARFrame references
            // let timestamp = frame.timestamp
            // Task { @MainActor in viewModel.processFrameData(timestamp: timestamp) }
        }

        nonisolated func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
            for anchor in anchors {
                if let imageAnchor = anchor as? ARImageAnchor {
                    Task { @MainActor in
                        viewModel.handleImageAnchorAdded(imageAnchor)
                    }
                }
            }
        }

        nonisolated func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
            for anchor in anchors {
                if let imageAnchor = anchor as? ARImageAnchor {
                    Task { @MainActor in
                        viewModel.handleImageAnchorUpdated(imageAnchor)
                    }
                }
            }
        }
    }
}

struct ARUnavailablePlaceholder: View {
    @Binding var isPresented: Bool

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: "arkit")
                    .font(.system(size: 56))
                    .foregroundStyle(.secondary)

                VStack(spacing: 8) {
                    Text("AR Experience")
                        .font(.title2.bold())

                    Text("Install this app on your device\nvia the Rork App for the full AR experience.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button("Go Back") {
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }
}
