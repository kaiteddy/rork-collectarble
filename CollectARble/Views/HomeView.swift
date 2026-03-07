import SwiftUI

struct HomeView: View {
    @Binding var showARExperience: Bool
    @Binding var selectedCreatureId: String
    @Binding var startInThrowMode: Bool
    @State private var appeared: Bool = false
    @State private var showCards: Bool = false
    @State private var selectedCard: CollectibleCard?

    private let accentBlue = Color(red: 0.0, green: 0.48, blue: 1.0)

    // Get cards from CollectibleCard
    private var pokemonCards: [CollectibleCard] {
        CollectibleCard.sampleCards.filter { $0.element == "Fire" }
    }

    private var footballCards: [CollectibleCard] {
        CollectibleCard.sampleCards.filter { $0.element == "Sports" }
    }

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
            CardCollectionView()
        }
        .sheet(item: $selectedCard) { card in
            HomeCardDetailSheet(
                card: card,
                onThrowToSummon: {
                    selectedCreatureId = card.creatureId
                    startInThrowMode = true
                    selectedCard = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showARExperience = true
                    }
                }
            )
        }
    }

    private let accentGold = Color(red: 1.0, green: 0.84, blue: 0.0)

    private var heroSection: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 40)

            // Animated card logo
            ZStack {
                // Outer glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [accentBlue.opacity(0.3), .clear],
                            center: .center,
                            startRadius: 30,
                            endRadius: 100
                        )
                    )
                    .frame(width: 200, height: 200)
                    .scaleEffect(appeared ? 1.0 : 0.5)

                // Card stack animation
                ZStack {
                    // Back card
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [accentGold.opacity(0.6), accentGold.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 70, height: 100)
                        .rotationEffect(.degrees(-12))
                        .offset(x: -15)

                    // Middle card
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [Color.orange.opacity(0.7), Color.red.opacity(0.5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 70, height: 100)
                        .rotationEffect(.degrees(0))

                    // Front card with AR icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [accentBlue, accentBlue.opacity(0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 70, height: 100)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(.white.opacity(0.4), lineWidth: 1.5)
                            )

                        VStack(spacing: 4) {
                            Image(systemName: "arkit")
                                .font(.system(size: 28, weight: .light))
                                .foregroundStyle(.white)

                            Text("AR")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.9))
                        }
                    }
                    .rotationEffect(.degrees(12))
                    .offset(x: 15)
                }
                .scaleEffect(appeared ? 1.0 : 0.6)

                // Sparkle effects
                Image(systemName: "sparkle")
                    .font(.system(size: 16))
                    .foregroundStyle(accentGold)
                    .offset(x: 50, y: -40)
                    .opacity(appeared ? 1 : 0)
                    .symbolEffect(.pulse, isActive: appeared)

                Image(systemName: "sparkle")
                    .font(.system(size: 12))
                    .foregroundStyle(accentBlue)
                    .offset(x: -55, y: 35)
                    .opacity(appeared ? 1 : 0)
                    .symbolEffect(.pulse, isActive: appeared)
            }
            .opacity(appeared ? 1 : 0)

            VStack(spacing: 12) {
                // CollectARble styled logo
                HStack(spacing: 0) {
                    Text("Collect")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    Text("AR")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundStyle(accentBlue)

                    Text("ble")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                }

                Text("Scan a card. Bring it to life.")
                    .font(.system(size: 16, weight: .medium))
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
        VStack(alignment: .leading, spacing: 24) {
            Text("Collections")
                .font(.title2.bold())
                .padding(.horizontal)

            // Pokemon Collection
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                    Text("Pokémon")
                        .font(.headline)
                }
                .padding(.horizontal)

                ScrollView(.horizontal) {
                    HStack(spacing: 16) {
                        ForEach(pokemonCards) { card in
                            CollectorCardPreview(card: card)
                                .onTapGesture {
                                    selectedCard = card
                                }
                        }
                    }
                }
                .contentMargins(.horizontal, 16)
                .scrollIndicators(.hidden)
            }

            // Football Collection
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "soccerball")
                        .foregroundStyle(.blue)
                    Text("Football")
                        .font(.headline)
                }
                .padding(.horizontal)

                ScrollView(.horizontal) {
                    HStack(spacing: 16) {
                        ForEach(footballCards) { card in
                            CollectorCardPreview(card: card)
                                .onTapGesture {
                                    selectedCard = card
                                }
                        }
                    }
                }
                .contentMargins(.horizontal, 16)
                .scrollIndicators(.hidden)
            }
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

// MARK: - Card Detail Sheet for Home Screen

struct HomeCardDetailSheet: View {
    let card: CollectibleCard
    let onThrowToSummon: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var rotation: Double = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Large 3D card view
                ZStack {
                    if card.creatureId == "charizard" {
                        CharizardCardView(rotation: $rotation)
                            .frame(height: 320)
                            .clipShape(.rect(cornerRadius: 16))
                            .shadow(color: .orange.opacity(0.5), radius: 20, y: 10)
                    } else {
                        SceneKitCardView(card: card, rotation: $rotation)
                            .frame(height: 320)
                            .clipShape(.rect(cornerRadius: 16))
                            .shadow(color: card.displayColor.opacity(0.5), radius: 20, y: 10)
                    }
                }
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            rotation += value.translation.width * 0.3
                        }
                )

                // Card info
                VStack(spacing: 12) {
                    Text(card.name)
                        .font(.title.bold())

                    HStack(spacing: 16) {
                        Label(card.element, systemImage: card.elementSymbol)
                            .foregroundStyle(card.displayColor)

                        Label(card.rarity.rawValue, systemImage: "star.fill")
                            .foregroundStyle(.yellow)

                        if card.isHolographic {
                            Label("Holo", systemImage: "sparkles")
                                .foregroundStyle(.purple)
                        }
                    }
                    .font(.subheadline)

                    Text(card.description)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer()

                // Throw to summon button
                Button {
                    dismiss()
                    onThrowToSummon()
                } label: {
                    HStack {
                        Image(systemName: card.creatureId == "messi" ? "soccerball" : "circle.fill")
                            .foregroundStyle(card.creatureId == "messi" ? .white : .red)
                        Text("Throw to Summon")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(card.displayColor, in: .rect(cornerRadius: 16))
                }
                .padding(.horizontal)
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }
}

// MARK: - Collector Card Preview for Home Screen

struct CollectorCardPreview: View {
    let card: CollectibleCard
    @State private var rotation: Double = 0

    var body: some View {
        VStack(spacing: 10) {
            // 3D Card Preview
            ZStack {
                if card.creatureId == "charizard" {
                    CharizardCardView(rotation: $rotation)
                        .frame(width: 140, height: 200)
                        .clipShape(.rect(cornerRadius: 12))
                        .shadow(color: .orange.opacity(0.5), radius: 10, y: 5)
                } else {
                    SceneKitCardView(card: card, rotation: $rotation)
                        .frame(width: 140, height: 200)
                        .clipShape(.rect(cornerRadius: 12))
                        .shadow(color: card.displayColor.opacity(0.4), radius: 10, y: 5)
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        rotation += value.translation.width * 0.5
                    }
            )

            // Card Info
            VStack(spacing: 4) {
                Text(card.name)
                    .font(.subheadline.weight(.semibold))

                HStack(spacing: 4) {
                    if card.isHolographic {
                        Image(systemName: "sparkles")
                            .font(.caption2)
                            .foregroundStyle(.purple)
                    }
                    Text(card.rarity.rawValue)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 150)
        .padding(.bottom, 8)
    }
}
