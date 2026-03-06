import SwiftUI
import RealityKit
import ARKit

struct ARExperienceView: View {
    @Binding var isPresented: Bool
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
    }

    private var arContent: some View {
        ZStack(alignment: .top) {
            ARViewContainer(viewModel: viewModel)
                .ignoresSafeArea()

            topBar

            VStack {
                Spacer()
                bottomControls
            }
        }
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

            if !viewModel.isCreatureSpawned && !viewModel.isPokeballAnimating {
                creatureSelector
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if viewModel.isCardDetected && !viewModel.isCreatureSpawned && !viewModel.isPokeballAnimating {
                cardDetectionIndicator
                    .transition(.scale.combined(with: .opacity))
            }

            if !viewModel.isCreatureSpawned && !viewModel.isCardDetected && !viewModel.isPokeballAnimating {
                scanHint
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if viewModel.isPokeballAnimating {
                pokeballHint
                    .transition(.scale.combined(with: .opacity))
            }

            if viewModel.isCreatureSpawned {
                interactionHint
                    .transition(.opacity)

                attackButton
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.bottom, 40)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: viewModel.isCreatureSpawned)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.isCardDetected)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.isPokeballAnimating)
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
        HStack(spacing: 10) {
            Image(systemName: "circle.fill")
                .font(.title3)
                .foregroundStyle(.red)
                .symbolEffect(.pulse, isActive: viewModel.isPokeballAnimating)

            VStack(alignment: .leading, spacing: 2) {
                Text("Pokéball activated!")
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
            HStack(spacing: 10) {
                Image(systemName: "bolt.fill")
                    .font(.title3)
                    .symbolEffect(.bounce, value: attackTrigger)

                if let creature = viewModel.currentCreature {
                    Text(creature.attackName)
                        .font(.headline)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                viewModel.currentCreature?.element.displayColor ?? accentBlue,
                in: .rect(cornerRadius: 16)
            )
            .opacity(viewModel.isAttacking ? 0.6 : 1.0)
        }
        .disabled(viewModel.isAttacking)
        .padding(.horizontal, 40)
        .sensoryFeedback(.impact(weight: .heavy), trigger: attackTrigger)
    }
}

struct ARViewContainer: UIViewRepresentable {
    let viewModel: ARViewModel

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        let coaching = ARCoachingOverlayView()
        coaching.session = arView.session
        coaching.goal = .horizontalPlane
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

            if viewModel.isCreatureSpawned {
                viewModel.triggerAttack()
                return
            }

            guard !viewModel.isPokeballAnimating else { return }

            let results = arView.raycast(from: location, allowing: .estimatedPlane, alignment: .horizontal)
            if let result = results.first {
                viewModel.spawnCreature(at: result.worldTransform)
                return
            }

            let fallback = arView.raycast(from: location, allowing: .existingPlaneGeometry, alignment: .horizontal)
            if let result = fallback.first {
                viewModel.spawnCreature(at: result.worldTransform)
            }
        }

        @objc func handlePan(_ sender: UIPanGestureRecognizer) {
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
            guard viewModel.isCreatureSpawned else { return }

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
            Task { @MainActor in
                viewModel.processFrame(frame)
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
