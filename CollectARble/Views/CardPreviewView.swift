import SwiftUI

struct CardPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCreature: Creature?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Text("Print these cards and point your camera at them to summon creatures in AR.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 16)], spacing: 16) {
                        ForEach(Creature.allCreatures) { creature in
                            Button {
                                selectedCreature = creature
                            } label: {
                                cardThumbnail(for: creature)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .navigationTitle("My Cards")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $selectedCreature) { creature in
                CardDetailSheet(creature: creature)
            }
        }
    }

    private func cardThumbnail(for creature: Creature) -> some View {
        VStack(spacing: 8) {
            CardImageView(creature: creature)
                .frame(height: 200)
                .clipShape(.rect(cornerRadius: 12))
                .shadow(color: creature.element.displayColor.opacity(0.3), radius: 8, y: 4)

            Text(creature.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
        }
    }
}

struct CardDetailSheet: View {
    let creature: Creature
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                CardImageView(creature: creature)
                    .frame(maxWidth: 280, maxHeight: 400)
                    .clipShape(.rect(cornerRadius: 16))
                    .shadow(color: creature.element.displayColor.opacity(0.4), radius: 16, y: 8)

                VStack(spacing: 6) {
                    Text(creature.name)
                        .font(.title2.bold())

                    Text(creature.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    HStack(spacing: 16) {
                        Label(creature.element.rawValue.capitalized, systemImage: creature.element.symbolName)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(creature.element.displayColor)

                        Label(creature.attackName, systemImage: "bolt.fill")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal)

                Text("Screenshot or print this card, then scan it with the AR camera.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Spacer()
            }
            .padding(.top, 24)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }
}

struct CardImageView: View {
    let creature: Creature
    @State private var cardImage: UIImage?

    var body: some View {
        Group {
            if let cardImage {
                Image(uiImage: cardImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Rectangle()
                    .fill(creature.element.displayColor.opacity(0.15))
                    .overlay {
                        ProgressView()
                    }
            }
        }
        .task {
            cardImage = CardReferenceService.renderCardImage(for: creature)
        }
    }
}
