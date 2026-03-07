import SwiftUI

struct SplashScreenView: View {
    @State private var phase: AnimationPhase = .initial
    @State private var cardRotation: Double = 0
    @State private var loadingProgress: CGFloat = 0

    let onComplete: () -> Void

    private let accentBlue = Color(red: 0.0, green: 0.48, blue: 1.0)
    private let accentGold = Color(red: 1.0, green: 0.84, blue: 0.0)

    private enum AnimationPhase {
        case initial
        case cardsAppear
        case logoAppear
        case taglineAppear
        case complete
    }

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.02, blue: 0.08),
                    Color(red: 0.05, green: 0.05, blue: 0.15),
                    Color(red: 0.03, green: 0.06, blue: 0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Subtle animated particles
            ParticleFieldView(accentBlue: accentBlue, accentGold: accentGold)
                .opacity(phase != .initial ? 1 : 0)
                .animation(.easeIn(duration: 1.5), value: phase)

            VStack(spacing: 40) {
                Spacer()

                // Card stack with smooth animations
                ZStack {
                    // Ambient glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [accentBlue.opacity(0.4), .clear],
                                center: .center,
                                startRadius: 30,
                                endRadius: 150
                            )
                        )
                        .frame(width: 300, height: 300)
                        .blur(radius: 40)
                        .opacity(phase != .initial ? 0.8 : 0)
                        .animation(.easeOut(duration: 1.2), value: phase)

                    // Back card
                    CardShape()
                        .fill(
                            LinearGradient(
                                colors: [Color.gray.opacity(0.4), Color.gray.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 90, height: 126)
                        .rotationEffect(.degrees(-18))
                        .offset(x: -25, y: 8)
                        .opacity(phase != .initial ? 0.7 : 0)
                        .scaleEffect(phase != .initial ? 1 : 0.8)
                        .animation(.spring(response: 0.9, dampingFraction: 0.75).delay(0.1), value: phase)

                    // Middle card (gold)
                    CardShape()
                        .fill(
                            LinearGradient(
                                colors: [accentGold.opacity(0.9), accentGold.opacity(0.5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 90, height: 126)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.white.opacity(0.4), lineWidth: 1.5)
                        )
                        .rotationEffect(.degrees(cardRotation * 0.3))
                        .offset(y: 4)
                        .opacity(phase != .initial ? 0.9 : 0)
                        .scaleEffect(phase != .initial ? 1 : 0.8)
                        .animation(.spring(response: 0.9, dampingFraction: 0.75).delay(0.2), value: phase)

                    // Front card with AR icon
                    ZStack {
                        CardShape()
                            .fill(
                                LinearGradient(
                                    colors: [accentBlue, accentBlue.opacity(0.75)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 90, height: 126)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.7), Color.white.opacity(0.2)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1.5
                                    )
                            )
                            .shadow(color: accentBlue.opacity(0.5), radius: 15, y: 8)

                        VStack(spacing: 6) {
                            Image(systemName: "arkit")
                                .font(.system(size: 32, weight: .light))
                                .foregroundStyle(.white)

                            Text("AR")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.9))
                        }
                    }
                    .rotation3DEffect(
                        .degrees(cardRotation),
                        axis: (x: 0, y: 1, z: 0),
                        perspective: 0.6
                    )
                    .rotationEffect(.degrees(18))
                    .offset(x: 20)
                    .opacity(phase != .initial ? 1 : 0)
                    .scaleEffect(phase != .initial ? 1 : 0.8)
                    .animation(.spring(response: 0.9, dampingFraction: 0.75).delay(0.3), value: phase)
                }
                .frame(height: 180)

                // Logo section
                VStack(spacing: 14) {
                    // CollectARble logo
                    HStack(spacing: 0) {
                        Text("Collect")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text("AR")
                            .font(.system(size: 36, weight: .black, design: .rounded))
                            .foregroundStyle(accentBlue)
                            .shadow(color: accentBlue.opacity(0.6), radius: 8)

                        Text("ble")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .opacity(phase == .logoAppear || phase == .taglineAppear || phase == .complete ? 1 : 0)
                    .offset(y: phase == .logoAppear || phase == .taglineAppear || phase == .complete ? 0 : 15)
                    .animation(.spring(response: 0.7, dampingFraction: 0.8), value: phase)

                    // Tagline
                    Text("Bring Your Cards to Life")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.65))
                        .opacity(phase == .taglineAppear || phase == .complete ? 1 : 0)
                        .offset(y: phase == .taglineAppear || phase == .complete ? 0 : 8)
                        .animation(.spring(response: 0.6, dampingFraction: 0.85).delay(0.15), value: phase)
                }

                Spacer()

                // Loading progress bar
                VStack(spacing: 12) {
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(.white.opacity(0.15))
                            .frame(width: 120, height: 3)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(
                                LinearGradient(
                                    colors: [accentBlue, accentBlue.opacity(0.7)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 120 * loadingProgress, height: 3)
                            .animation(.easeInOut(duration: 0.1), value: loadingProgress)
                    }
                }
                .opacity(phase != .initial && phase != .complete ? 1 : 0)
                .animation(.easeInOut(duration: 0.3), value: phase)
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            startAnimations()
        }
    }

    private func startAnimations() {
        // Phase 1: Cards appear
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            phase = .cardsAppear
        }

        // Start gentle card rotation
        withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true).delay(0.5)) {
            cardRotation = 12
        }

        // Phase 2: Logo appears
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            phase = .logoAppear
        }

        // Phase 3: Tagline appears
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            phase = .taglineAppear
        }

        // Animate loading bar smoothly
        animateLoading()

        // Complete and transition
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.3) {
            phase = .complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                onComplete()
            }
        }
    }

    private func animateLoading() {
        let steps = 25
        let duration = 1.8
        let stepDuration = duration / Double(steps)

        for i in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5 + Double(i) * stepDuration) {
                withAnimation(.linear(duration: stepDuration)) {
                    loadingProgress = CGFloat(i) / CGFloat(steps)
                }
            }
        }
    }
}

// MARK: - Card Shape

private struct CardShape: Shape {
    func path(in rect: CGRect) -> Path {
        RoundedRectangle(cornerRadius: 12).path(in: rect)
    }
}

// MARK: - Particle Field

private struct ParticleFieldView: View {
    let accentBlue: Color
    let accentGold: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<15, id: \.self) { index in
                    ParticleView(
                        color: index % 3 == 0 ? accentGold : accentBlue.opacity(0.7),
                        size: CGFloat.random(in: 2...5),
                        screenSize: geometry.size,
                        delay: Double(index) * 0.12
                    )
                }
            }
        }
    }
}

private struct ParticleView: View {
    let color: Color
    let size: CGFloat
    let screenSize: CGSize
    let delay: Double

    @State private var yOffset: CGFloat = 0
    @State private var opacity: Double = 0

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .blur(radius: size > 3 ? 1 : 0)
            .position(
                x: CGFloat.random(in: screenSize.width * 0.1...screenSize.width * 0.9),
                y: screenSize.height * 0.3 + yOffset
            )
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: 0.8).delay(delay)) {
                    opacity = Double.random(in: 0.3...0.6)
                }
                withAnimation(
                    .easeInOut(duration: Double.random(in: 2.5...4))
                    .repeatForever(autoreverses: true)
                    .delay(delay)
                ) {
                    yOffset = CGFloat.random(in: -60...60)
                }
            }
    }
}

#Preview {
    SplashScreenView(onComplete: {})
}
