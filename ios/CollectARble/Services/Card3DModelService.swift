import SceneKit
import UIKit

/// Service for loading and displaying 3D card models
struct Card3DModelService {

    /// Model names for 3D cards by creature ID
    static func possibleModelNames(for creatureId: String) -> [String] {
        switch creatureId {
        case "charizard":
            return [
                "Pokemon_TCG_Charizard_1st_Edition",
                "PokemonTCGCharizard1stEdition",
                "pokemon_tcg_charizard_1st_edition",
                "Pokemon TCG Charizard 1st Edition",
                "Charizard_Card",
                "charizard_card",
                "Charizard",
                "charizard"
            ]
        default:
            return []
        }
    }

    /// Check if a creature has a 3D card model in the bundle
    static func has3DCard(for creatureId: String) -> Bool {
        return modelURL(for: creatureId) != nil
    }

    /// Get the URL for a 3D card model
    static func modelURL(for creatureId: String) -> URL? {
        let possibleNames = possibleModelNames(for: creatureId)

        // First, try exact names
        for name in possibleNames {
            if let url = Bundle.main.url(forResource: name, withExtension: "usdz") {
                print("DEBUG: Found 3D card model: \(name).usdz")
                return url
            }
        }

        // Try scanning the bundle for any file containing "charizard" (case insensitive)
        if creatureId == "charizard" {
            if let resourcePath = Bundle.main.resourcePath {
                do {
                    let files = try FileManager.default.contentsOfDirectory(atPath: resourcePath)
                    for file in files {
                        if file.lowercased().contains("charizard") && file.hasSuffix(".usdz") {
                            let url = URL(fileURLWithPath: resourcePath).appendingPathComponent(file)
                            print("DEBUG: Found Charizard model via scan: \(file)")
                            return url
                        }
                    }
                } catch {
                    print("DEBUG: Could not scan bundle: \(error)")
                }
            }
        }

        print("DEBUG: 3D card model not found in bundle for \(creatureId)")
        return nil
    }

    /// List all USDZ files in the bundle (for debugging)
    static func listAllUSDZFiles() -> [String] {
        var usdzFiles: [String] = []

        if let resourcePath = Bundle.main.resourcePath {
            do {
                let files = try FileManager.default.contentsOfDirectory(atPath: resourcePath)
                usdzFiles = files.filter { $0.hasSuffix(".usdz") }
                print("DEBUG: All USDZ files in bundle: \(usdzFiles)")
            } catch {
                print("DEBUG: Could not list bundle contents: \(error)")
            }
        }

        return usdzFiles
    }
}
