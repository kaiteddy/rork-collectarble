import SwiftUI

struct HomeView: View {
    @Binding var showARExperience: Bool
    @State private var appeared: Bool = false
    @State private var showCards: Bool = false

    private let accentBlue = Color(red: 0.0, green: 0.48, blue: 1.0)

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                heroSection
                creaturesSection
                howItWorksSection
            }
        }
        .background(Color(.systemBackground))
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                appeared = true
            }
        }
        .sheet(isPresented: $showCards) {
            CardPreviewView()
        }
    }

    private var heroSection: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 60)

            ZStack {
                Circle()
                    .fill(accentBlue.opacity(0.08))
                    .frame(width: 160, height: 160)
                    .scaleEffect(appeared ? 1.0 : 0.5)

                Circle()
                    .fill(accentBlue.opacity(0.04))
                    .frame(width: 220, height: 220)
                    .scaleEffect(appeared ? 1.0 : 0.3)

                Image(systemName: "cube.transparent")
                    .font(.system(size: 64, weight: .light))
                    .foregroundStyle(accentBlue)
                    .symbolEffect(.breathe, isActive: appeared)
                    .scaleEffect(appeared ? 1.0 : 0.6)
            }
            .opacity(appeared ? 1 : 0)

            VStack(spacing: 8) {
                Text("CollectARble")
                    .font(.system(.largeTitle, design: .default, weight: .bold))

                Text("Scan a card. Bring it to life.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)

            VStack(spacing: 12) {
                Button {
                    showARExperience = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "camera.viewfinder")
                            .font(.title3)
                        Text("Scan Card")
                            .font(.headline)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(accentBlue, in: .rect(cornerRadius: 16))
                }

                Button {
                    showCards = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "rectangle.stack.fill")
                            .font(.title3)
                        Text("My Cards")
                            .font(.headline)
                    }
                    .foregroundStyle(accentBlue)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(accentBlue.opacity(0.1), in: .rect(cornerRadius: 16))
                }
            }
            .padding(.horizontal, 40)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 30)

            Spacer().frame(height: 8)
        }
    }

    private var creaturesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Creatures")
                .font(.title2.bold())
                .padding(.horizontal)

            ScrollView(.horizontal) {
                HStack(spacing: 14) {
                    ForEach(Creature.allCreatures) { creature in
                        CreatureCard(creature: creature)
                    }
                }
            }
            .contentMargins(.horizontal, 16)
            .scrollIndicators(.hidden)
        }
        .padding(.top, 32)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 40)
    }

    private var howItWorksSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("How It Works")
                .font(.title2.bold())
                .padding(.horizontal)

            VStack(spacing: 16) {
                StepRow(
                    number: 1,
                    icon: "rectangle.stack.fill",
                    title: "Get Your Cards",
                    subtitle: "View and print your CollectARble cards from the My Cards section"
                )
                StepRow(
                    number: 2,
                    icon: "viewfinder",
                    title: "Scan a Card",
                    subtitle: "Point your phone camera at a printed card to detect it"
                )
                StepRow(
                    number: 3,
                    icon: "sparkles",
                    title: "Watch It Come Alive",
                    subtitle: "Your creature appears in augmented reality on the card"
                )
                StepRow(
                    number: 4,
                    icon: "bolt.fill",
                    title: "Trigger the Attack",
                    subtitle: "Tap the Attack button to unleash their signature ability"
                )
            }
            .padding(.horizontal)

            Spacer().frame(height: 40)
        }
        .padding(.top, 36)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 50)
    }
}

struct CreatureCard: View {
    let creature: Creature

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(creature.element.displayColor.opacity(0.12))
                    .frame(height: 120)

                VStack(spacing: 8) {
                    Image(systemName: creature.element.symbolName)
                        .font(.system(size: 36))
                        .foregroundStyle(creature.element.displayColor)

                    Image(systemName: "diamond.fill")
                        .font(.caption2)
                        .foregroundStyle(creature.element.displayColor.opacity(0.5))
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(creature.name)
                    .font(.headline)

                Text(creature.attackName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
        }
        .frame(width: 150)
        .padding(.bottom, 8)
    }
}

struct StepRow: View {
    let number: Int
    let icon: String
    let title: String
    let subtitle: String

    private let accentBlue = Color(red: 0.0, green: 0.48, blue: 1.0)

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(accentBlue.opacity(0.1))
                    .frame(width: 48, height: 48)

                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(accentBlue)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(14)
        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 14))
    }
}
