You are a senior iOS developer. Generate the complete Swift/SwiftUI source code for a native iOS dashboard app that controls Hermes Agent (an AI agent framework) over its REST API.

The architecture was designed by a planning agent. Read ARCHITECTURE.md if it exists in this directory for the detailed plan. If it doesn't exist yet, design and code simultaneously based on these requirements:

## API (Hermes API Server)
- Base URL: http://<tailscale-ip>:8642
- Auth: Bearer token in Authorization header
- Key endpoints: /v1/chat/completions, /v1/runs, /api/sessions, /api/jobs, /v1/skills, /v1/toolsets, /health

## App Features
1. Chat with Hermes (streaming SSE support)
2. Session management (list, view history, fork)
3. Cron job management (list, create, pause, resume, run, delete)
4. Settings (server URL, API key stored in Keychain)
5. Status dashboard (health, capabilities, skills, toolsets)
6. Dark mode native support

## Technical Requirements
- SwiftUI with iOS 17+ target
- MVVM architecture with @Observable
- async/await networking with URLSession
- SSE streaming for real-time chat
- SwiftData for local caching
- Keychain for API key storage
- No external dependencies beyond Apple frameworks (URLSession, SwiftUI, SwiftData, Security framework)
- Proper error handling with user-friendly messages
- Loading states and empty states for all views
- TabView navigation with SF Symbols

## Project Structure
Create all files in an Xcode-project-like structure. Save each file to the `HermesApp/` subdirectory. The files needed:

1. HermesApp.swift - App entry point
2. ContentView.swift - TabView root
3. Models/ - All Codable API models
4. Networking/ - API client, SSE parser
5. ViewModels/ - @Observable view models
6. Views/Chat/ - Chat list + detail
7. Views/Sessions/ - Session list + detail + messages
8. Views/Jobs/ - Job list + detail + create form
9. Views/Settings/ - Settings form
10. Views/Status/ - Status dashboard
11. Utilities/ - Keychain wrapper, error types, extensions

Write complete, compilable Swift code. Every file should be fully implemented, not stubs.
