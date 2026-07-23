# Hermes iOS App

Native iOS client for the **Hermes Agent** — a self-hosted AI assistant platform. Built with SwiftUI, targeting iOS 17+.

## Features

- **Chat** — real-time streaming conversations with the Hermes agent
- **Sessions** — organize conversations, fork and revisit past sessions
- **Jobs** — view, create, and manage cron-scheduled tasks on the Hermes server
- **Status** — monitor server health, enabled skills, and available toolsets
- **Settings** — configure server URL, API key, and model selection

## Requirements

- iOS 17+
- Xcode 15+
- A running [Hermes Agent](https://github.com/hermes-org/hermes) server
- Tailscale (recommended for remote access) or local network connectivity

## Setup

### 1. Clone and open

```bash
git clone <repo-url> hermes-ios-app
cd hermes-ios-app
open HermesApp.xcodeproj
```

### 2. Tailscale configuration

The default server URL points to a Tailscale node at `100.115.248.107:8642`. If you are using Tailscale:

1. Install Tailscale on your iOS device and the server machine
2. Connect both to the same tailnet
3. Find your server's Tailscale IP: run `tailscale ip -4` on the server
4. Update the server URL in the app Settings to `http://<tailscale-ip>:8642`

**Important**: The app's `Info.plist` sets `NSAllowsLocalNetworking = YES`. For Tailscale CGNAT IPs (100.x.x.x), you may need to add an App Transport Security exception or enable `NSAllowsArbitraryLoads`. Add this to `Info.plist` if needed:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSExceptionDomains</key>
    <dict>
        <key>100.115.248.107</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <true/>
            <key>NSIncludesSubdomains</key>
            <true/>
        </dict>
    </dict>
</dict>
```

### 3. API Key setup

The API key is **not hardcoded** in production builds — it is stored securely in the iOS Keychain. On first launch:

1. Open the **Settings** tab
2. Enter your Hermes server URL (e.g. `http://100.115.248.107:8642`)
3. Enter the API key configured on your Hermes server (via `HERMES_API_KEY` env var or `config.yaml`)
4. Tap **Save Configuration**

The API key is persisted in the Keychain and never stored in `UserDefaults`.

### 4. Build and run

Select your target device or simulator and press **Run** (⌘R).

## Architecture

```
HermesApp/
├── Models/          – Codable types matching the API contract
├── Networking/      – APIClient, HermesClient, Endpoints, SSE parser
├── Utilities/       – Keychain wrappers, error types, extensions
├── ViewModels/      – @Observable view models (iOS 17 observation)
├── Views/           – SwiftUI views organized by feature
│   ├── Chat/
│   ├── Sessions/
│   ├── Jobs/
│   ├── Status/
│   └── Settings/
├── HermesApp.swift  – App entry point
└── ContentView.swift – Root tab navigator
```

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Server health status |
| `/v1/chat/completions` | POST | Streaming chat completion |
| `/v1/capabilities` | GET | Server capabilities |
| `/v1/skills` | GET | Enabled skills |
| `/v1/toolsets` | GET | Available toolsets |
| `/api/sessions` | GET/POST | List / create sessions |
| `/api/sessions/:id` | GET/PUT/DELETE | Session CRUD |
| `/api/sessions/:id/messages` | GET | Session messages |
| `/api/jobs` | GET/POST | List / create cron jobs |
| `/api/jobs/:id` | PUT/DELETE | Update / delete job |

## Running Tests

```bash
xcodebuild test -scheme HermesApp -destination 'platform=iOS Simulator,name=iPhone 15' -testPlan HermesAppTests
```

Tests cover:
- **APIClient**: request building, response handling, SSE parsing, keychain integration
- **Model decoding**: JSON decoding for all API types, edge cases, coding key mapping
- **ViewModel state**: initial state, clear/cancel operations, configuration checks
