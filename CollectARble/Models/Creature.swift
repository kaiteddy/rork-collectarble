import SwiftUI

nonisolated struct Creature: Identifiable, Sendable {
    let id: String
    let name: String
    let element: Element
    let attackName: String
    let description: String
    let bundledModelName: String?

    nonisolated enum Element: String, Sendable {
        case fire, ice, nature

        var primaryColor: UIColor {
            switch self {
            case .fire: UIColor(red: 1.0, green: 0.35, blue: 0.15, alpha: 1.0)
            case .ice: UIColor(red: 0.3, green: 0.7, blue: 1.0, alpha: 1.0)
            case .nature: UIColor(red: 0.2, green: 0.85, blue: 0.4, alpha: 1.0)
            }
        }

        var secondaryColor: UIColor {
            switch self {
            case .fire: UIColor(red: 1.0, green: 0.8, blue: 0.1, alpha: 1.0)
            case .ice: UIColor(red: 0.85, green: 0.95, blue: 1.0, alpha: 1.0)
            case .nature: UIColor(red: 0.6, green: 1.0, blue: 0.3, alpha: 1.0)
            }
        }

        var symbolName: String {
            switch self {
            case .fire: "flame.fill"
            case .ice: "snowflake"
            case .nature: "leaf.fill"
            }
        }

        var displayColor: Color {
            Color(uiColor: primaryColor)
        }
    }

    static let allCreatures: [Creature] = [
        Creature(
            id: "charizard",
            name: "Charizard",
            element: .fire,
            attackName: "Flamethrower",
            description: "A fearsome fire-breathing dragon that soars through the skies.",
            bundledModelName: "Charizard_SV"
        ),
        Creature(
            id: "glacius",
            name: "Glacius",
            element: .ice,
            attackName: "Frost Nova",
            description: "An ancient ice guardian from the frozen peaks.",
            bundledModelName: nil
        ),
        Creature(
            id: "verdant",
            name: "Verdant",
            element: .nature,
            attackName: "Thorn Storm",
            description: "A nature spirit who commands the power of the forest.",
            bundledModelName: nil
        ),
    ]

    static func creature(forImageName name: String) -> Creature? {
        allCreatures.first { $0.id == name }
    }
}
