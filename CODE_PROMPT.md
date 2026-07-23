You are a senior iOS developer. Generate a COMPLETE native SwiftUI app for Hermes Agent dashboard.

## API
Base: http://100.115.248.107:8642, Auth: Bearer token
Endpoints: /v1/chat/completions, /v1/responses, /v1/runs, /v1/runs/{id}/events (SSE), /api/sessions (CRUD), /api/sessions/{id}/chat/stream, /v1/skills, /v1/toolsets, /health, /v1/capabilities

## Requirements
- iOS 17+, SwiftUI, @Observable, async/await, URLSession
- No external dependencies (pure Apple frameworks)
- All files fully implemented, not stubs
- Dark mode, loading states, error handling, empty states

## Files to create in HermesApp/:
- HermesApp.swift (entry), ContentView.swift (TabView)
- Models/APITypes.swift (all Codable models)
- Networking/HermesClient.swift (async API client)
- Networking/SSEParser.swift (SSE stream parser)
- Utilities/KeychainManager.swift
- Utilities/AppError.swift
- ViewModels/ChatViewModel.swift
- ViewModels/SessionsViewModel.swift
- ViewModels/StatusViewModel.swift
- ViewModels/SettingsViewModel.swift
- Views/Chat/ChatListView.swift
- Views/Chat/ChatDetailView.swift
- Views/Sessions/SessionsListView.swift
- Views/Sessions/SessionDetailView.swift
- Views/Status/StatusDashboardView.swift
- Views/Settings/SettingsView.swift
