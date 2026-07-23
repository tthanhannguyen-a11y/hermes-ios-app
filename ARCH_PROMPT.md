You are an iOS architect. Design a complete native SwiftUI iOS dashboard app for Hermes Agent that connects over Tailscale VPN to a Hermes API server.

## Hermes API Server (live, verified)
- Base URL: http://100.115.248.107:8642
- Auth: Bearer token (hermes-ios-app-key-2026)
- Key endpoints verified:
  - POST /v1/chat/completions (streaming)
  - POST /v1/responses (with previous_response_id chaining)
  - POST /v1/runs + GET /v1/runs/{id}/events (SSE)
  - GET/POST /api/sessions, GET/PATCH/DELETE /api/sessions/{id}
  - POST /api/sessions/{id}/chat, POST /api/sessions/{id}/chat/stream
  - GET /api/sessions/{id}/messages
  - GET /v1/skills, GET /v1/toolsets
  - GET /health, GET /v1/capabilities

## Required Screens
1. Chat tab: session list + chat detail with streaming SSE
2. Sessions tab: list, view messages, fork
3. Status tab: health, capabilities, skills, toolsets
4. Settings tab: server URL, API key (Keychain), app info

## Deliverables in ARCHITECTURE.md
1. SwiftUI view hierarchy + NavigationStack/TabView structure
2. Networking layer: async/await API client, SSE stream parser
3. Data models: Codable structs for all API responses
4. State management: @Observable view models
5. Project file tree: every Swift file with 1-line purpose
6. Auth flow: Keychain → API client injection
7. Error handling strategy
8. Dark mode + loading/empty states
