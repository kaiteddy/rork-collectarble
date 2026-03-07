// Config.swift - Auto-generated at build time
// Environment variables from Project Settings are injected here
//
// Usage: Config.YOUR_ENV_NAME
// Example: If you set MY_API_KEY in Environment Variables,
//          use Config.MY_API_KEY in your code

import Foundation

enum Config {
    // Environment variables will be injected here at build time
    // Add your ENV in Project Settings → Environment Variables
    // Then use Config.YOUR_ENV_NAME in code

    /// Anthropic API key for Claude-powered character chat
    /// Set ANTHROPIC_API_KEY in Xcode scheme environment variables
    nonisolated static var anthropicAPIKey: String {
        ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? ""
    }
}
