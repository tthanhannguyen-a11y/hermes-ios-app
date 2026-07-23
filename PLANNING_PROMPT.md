You are an iOS architect. Design a complete native SwiftUI iOS app that acts as a full dashboard for Hermes Agent (an AI agent framework running on a Windows PC).

## Context
- Hermes runs on Windows 10 PC with Tailscale VPN (free, already configured)
- Hermes has a gateway that exposes an API Server (REST endpoints)
- The iOS app connects to Hermes over Tailscale (stable private IP)
- Features needed: Chat, Sessions, Cron jobs, Config, Tools, Status

## Deliverables
1. **Architecture overview**: Component tree, data flow, navigation structure
2. **API contract**: All REST endpoints the iOS app needs (base the design on Hermes gateway API patterns - chat, sessions, cron, config, tools, status)
3. **SwiftUI view hierarchy**: Every screen, navigation pattern (TabView + NavigationStack)
4. **Data layer**: Models, networking layer (async/await, URLSession), local persistence (SwiftData)
5. **Connectivity**: How the app discovers and connects to Hermes over Tailscale
6. **Security**: API key handling, Keychain storage, TLS considerations
7. **File structure**: Complete Xcode project layout with all files listed

Output as a detailed markdown document. Be thorough and specific - this will be fed directly to a coding agent.
