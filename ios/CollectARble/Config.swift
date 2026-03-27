// Config.swift - Configuration for CollectARble
//
// API Key Setup Options (in order of priority):
// 1. Info.plist: Add "ANTHROPIC_API_KEY" key with your API key value
// 2. Secrets.plist: Create Secrets.plist in bundle with "ANTHROPIC_API_KEY" key
// 3. Environment Variable: Set ANTHROPIC_API_KEY in Xcode scheme (dev only)

import Foundation

enum Config {
    /// Anthropic API key for Claude-powered character chat
    /// Checks multiple sources: Info.plist, Secrets.plist, then environment
    static var anthropicAPIKey: String {
        // 1. Check Info.plist first (most reliable for distribution)
        if let key = Bundle.main.object(forInfoDictionaryKey: "ANTHROPIC_API_KEY") as? String,
           !key.isEmpty, !key.hasPrefix("$") {
            return key
        }

        // 2. Check for Secrets.plist (keeps secrets out of Info.plist)
        if let secretsPath = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
           let secrets = NSDictionary(contentsOfFile: secretsPath),
           let key = secrets["ANTHROPIC_API_KEY"] as? String,
           !key.isEmpty {
            return key
        }

        // 3. Fall back to environment variable (works in Xcode debug)
        if let key = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"],
           !key.isEmpty {
            return key
        }

        return ""
    }
}
