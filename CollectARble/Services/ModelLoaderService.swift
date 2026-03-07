import Foundation
import RealityKit

nonisolated enum ModelLoadError: Error, Sendable {
    case fileNotFound(String)
    case loadFailed
    case downloadFailed
}

enum ModelLoaderService {
    static func downloadModel(from url: URL) async throws -> URL {
        let cache = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let local = cache.appendingPathComponent(url.lastPathComponent)
        if FileManager.default.fileExists(atPath: local.path),
           let attrs = try? FileManager.default.attributesOfItem(atPath: local.path),
           let size = attrs[.size] as? Int, size > 0 {
            return local
        }
        let (temp, response) = try await URLSession.shared.download(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw ModelLoadError.downloadFailed
        }
        try? FileManager.default.removeItem(at: local)
        try FileManager.default.moveItem(at: temp, to: local)
        return local
    }

    @MainActor
    static func loadBundledModel(named name: String) async throws -> Entity {
        guard let url = Bundle.main.url(forResource: name, withExtension: "usdz") else {
            throw ModelLoadError.fileNotFound(name)
        }
        let entity = try await Entity(contentsOf: url)
        return entity
    }
}
