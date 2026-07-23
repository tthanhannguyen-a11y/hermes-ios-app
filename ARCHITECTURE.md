# Hermes iOS Dashboard — Architecture

**Status:** Approved for implementation. This document is the single source of truth for the coding agent. Implement exactly what is specified here; where the server schema is uncertain, follow the tolerance rules in §14.

---

## 1. Overview

A native iOS dashboard app ("HermesApp") that monitors and controls **Hermes Agent**, an AI agent framework running on a Windows 10 PC. The app talks to the Hermes gateway API server over **Tailscale** (WireGuard-encrypted private network, stable `100.x.y.z` IP).

### 1.1 Goals

| Feature | Description |
|---|---|
| Chat | Streaming (SSE) conversation with Hermes |
| Sessions | Browse, inspect, fork, delete, and continue past sessions |
| Cron Jobs | List, create, pause, resume, run-now, delete scheduled jobs |
| Status | Health, capabilities, skills, toolsets, recent runs |
| Config | View and edit agent configuration (surfaced inside Status tab) |
| Settings | Server URL, API key (Keychain), theme, connection test |

### 1.2 Constraints

- **iOS 17.0+**, Swift 5.9+, SwiftUI only (no UIKit except where unavoidable).
- **Zero third-party dependencies.** Apple frameworks only: SwiftUI, SwiftData, Foundation (URLSession), Network (NWPathMonitor), Security (Keychain), OSLog.
- **MVVM** with `@Observable` (Observation framework). No Combine, no RxSwift.
- All networking with `async/await` + `URLSession`. No completion-handler APIs.
- Xcode project-like folder structure under `HermesApp/` (see §13).

---

## 2. High-Level Architecture

### 2.1 Layer diagram

```
┌────────────────────────────────────────────────────────────┐
│                         VIEWS (SwiftUI)                     │
│  Chat · Sessions · Jobs · Status · Settings · Components    │
├────────────────────────────────────────────────────────────┤
│               VIEW MODELS (@MainActor @Observable)          │
│     LoadState<T> · intents (send/load/create/delete)        │
├──────────────────┬──────────────────────┬──────────────────┤
│   NETWORKING     │      SERVICES        │    PERSISTENCE    │
│ HermesAPIClient  │ SettingsStore        │ SwiftData @Model  │
│ Endpoint enum    │ KeychainStore        │ CachedSession     │
│ SSEParser        │ ConnectivityMonitor  │ CachedMessage     │
│                  │ CacheStore           │ CachedJob/Status  │
└──────────────────┴──────────────────────┴──────────────────┘
                 │  HTTP + SSE over Tailscale (WireGuard)
                 ▼
        Hermes gateway API (http://<tailscale-ip>:8642)
```

### 2.2 Data flow (unidirectional)

```
User action
   │
   ▼
View ──intent──▶ ViewModel (@MainActor)
   ▲                │
   │                ▼
   │          HermesAPIClient.request/stream  (async, off-main)
   │                │
   │                ▼
   │          DTO decoded (Codable)  ──▶ CacheStore.save (SwiftData)
   │                │
   └────@Observable mutation────────┘
        SwiftUI re-renders
```

Rules:
- Views never call the API client directly. They call ViewModel methods.
- ViewModels never construct `URLRequest`s. They call typed client methods.
- The client returns DTOs (plain `Codable` structs). SwiftData `@Model` classes are used **only** for offline caching and never appear in ViewModels/Views — ViewModels map DTOs ↔ cached models.
- On successful fetch, the ViewModel updates state **and** writes through to the cache. On network failure, the ViewModel falls back to cached data and flags it stale (see §10).

---

## 3. API Contract

### 3.1 Conventions

| Item | Value |
|---|---|
| Base URL | `http://<host>:8642` — `host` is user-configurable (Tailscale IPv4 or MagicDNS name) |
| Auth | `Authorization: Bearer <api-key>` on **every** request except none (health also takes it; send it always) |
| Content-Type | `application/json; charset=utf-8` for bodies; `Accept: application/json` (`text/event-stream` for streaming) |
| List envelope | `{ "object": "list", "data": [ ... ] }` (tolerate bare arrays — see §14) |
| Single envelope | `{ "data": { ... } }` (tolerate bare objects) |
| Error envelope | `{ "error": { "message": String, "type": String?, "code": String? } }` |
| Timestamps | ISO-8601 (`2026-07-23T10:15:30Z`), possibly with fractional seconds |
| IDs | Server-generated opaque strings (`ses_…`, `job_…`, `msg_…`) |

### 3.2 Endpoint reference

| # | Method & Path | Purpose | Auth | Success |
|---|---|---|---|---|
| 1 | `GET /health` | Liveness + version | ✓ | `200 HealthStatus` |
| 2 | `POST /v1/chat/completions` | Chat (non-streaming) | ✓ | `200 ChatCompletionResponse` |
| 3 | `POST /v1/chat/completions` (`stream:true`) | Chat (SSE stream) | ✓ | `200 text/event-stream` |
| 4 | `GET /v1/runs` | Recent agent runs | ✓ | `200 {data:[Run]}` |
| 5 | `GET /api/sessions` | List sessions (newest first) | ✓ | `200 {data:[Session]}` |
| 6 | `GET /api/sessions/{id}` | One session | ✓ | `200 {data:Session}` |
| 7 | `GET /api/sessions/{id}/messages` | Full message history | ✓ | `200 {data:[SessionMessage]}` |
| 8 | `POST /api/sessions/{id}/fork` | Duplicate session | ✓ | `200 {data:Session}` |
| 9 | `DELETE /api/sessions/{id}` | Delete session | ✓ | `204` |
| 10 | `GET /api/jobs` | List cron jobs | ✓ | `200 {data:[CronJob]}` |
| 11 | `POST /api/jobs` | Create job | ✓ | `201 {data:CronJob}` |
| 12 | `PATCH /api/jobs/{id}` | Edit job (name/prompt/schedule) | ✓ | `200 {data:CronJob}` |
| 13 | `POST /api/jobs/{id}/pause` | Disable job | ✓ | `200 {data:CronJob}` |
| 14 | `POST /api/jobs/{id}/resume` | Enable job | ✓ | `200 {data:CronJob}` |
| 15 | `POST /api/jobs/{id}/run` | Trigger immediate run | ✓ | `202 {data:{run_id}}` |
| 16 | `DELETE /api/jobs/{id}` | Delete job | ✓ | `204` |
| 17 | `GET /v1/skills` | List skills | ✓ | `200 {data:[Skill]}` |
| 18 | `GET /v1/toolsets` | List toolsets + tools | ✓ | `200 {data:[Toolset]}` |
| 19 | `GET /api/config` | Agent configuration | ✓ | `200 {data:{key:value}}` |
| 20 | `PATCH /api/config` | Update configuration keys | ✓ | `200 {data:{key:value}}` |

### 3.3 Payloads

**`POST /v1/chat/completions` request**
```json
{
  "model": "hermes",
  "messages": [
    { "role": "system", "content": "…" },
    { "role": "user",   "content": "Hello" }
  ],
  "stream": true,
  "session_id": "ses_abc123"        // optional; omit to start a new session
}
```

**Non-streaming response** (`stream:false`, OpenAI-style):
```json
{
  "id": "chatcmpl_1",
  "object": "chat.completion",
  "created": 1753262400,
  "model": "hermes",
  "choices": [
    { "index": 0,
      "message": { "role": "assistant", "content": "Hi!" },
      "finish_reason": "stop" }
  ],
  "session_id": "ses_abc123"
}
```

**Streaming response** — SSE, one event per line pair:
```
data: {"id":"chatcmpl_1","object":"chat.completion.chunk","choices":[{"index":0,"delta":{"role":"assistant","content":"Hi"},"finish_reason":null}]}

data: {"id":"chatcmpl_1","object":"chat.completion.chunk","choices":[{"index":0,"delta":{"content":"!"},"finish_reason":null}]}

data: {"id":"chatcmpl_1","object":"chat.completion.chunk","choices":[{"index":0,"delta":{},"finish_reason":"stop"}],"session_id":"ses_abc123"}

data: [DONE]
```

**`Session`**
```json
{ "id": "ses_abc123", "title": "Refactor parser", "model": "hermes",
  "status": "active", "message_count": 12,
  "created_at": "2026-07-23T09:00:00Z", "updated_at": "2026-07-23T10:15:30Z" }
```

**`SessionMessage`**
```json
{ "id": "msg_1", "role": "assistant", "content": "Done.",
  "created_at": "2026-07-23T10:15:30Z",
  "tool_calls": [ { "name": "read_file", "arguments": "{\"path\":\"a.swift\"}" } ] }
```

**`CronJob`**
```json
{ "id": "job_42", "name": "Morning briefing", "prompt": "Summarize overnight logs",
  "schedule": "0 9 * * *", "enabled": true,
  "last_run_at": "2026-07-23T09:00:00Z", "next_run_at": "2026-07-24T09:00:00Z",
  "last_status": "success", "created_at": "2026-07-01T08:00:00Z" }
```
`last_status` ∈ `"success" | "failed" | "running" | "never"`. Create/update body: `{ "name", "prompt", "schedule", "enabled" }`.

**`Skill`** — `{ "id": "skill.web_search", "name": "Web Search", "description": "…", "enabled": true }`

**`Toolset`** — `{ "id": "filesystem", "name": "Filesystem", "description": "…", "tools": [ { "name": "read_file", "description": "…" } ] }`

**`HealthStatus`** — `{ "status": "ok", "version": "1.4.2", "uptime_seconds": 12345, "model": "hermes" }`

**`Run`** — `{ "id": "run_9", "session_id": "ses_abc123", "status": "completed", "started_at": "…", "finished_at": "…" }`

**Config** — `GET /api/config` → `{ "data": { "model": "hermes", "max_tokens": 4096, "verbose": false, … } }`. Keys are dynamic → decode into a `JSONValue` dictionary (§4). `PATCH` body: `{ "max_tokens": 8192 }`.

---

## 4. Data Models

Two model tiers. **Never share types between tiers.**

### 4.1 DTOs (Codable structs, `Models/`)

All DTOs are `struct … : Codable, Sendable, Identifiable, Hashable` (Hashable/Identifiable where sensible). All server fields optional unless guaranteed, per §14 tolerance rules.

```swift
// ChatModels.swift
enum MessageRole: String, Codable, Sendable { case system, user, assistant, tool, unknown }

struct ChatMessage: Identifiable, Hashable, Sendable {       // UI-level message (local, not decoded)
    let id: UUID
    var role: MessageRole
    var content: String
    var isStreaming: Bool
    var timestamp: Date
}

struct ChatCompletionRequest: Encodable, Sendable {
    var model: String
    var messages: [RequestMessage]      // { role: String, content: String }
    var stream: Bool
    var sessionID: String?              // "session_id"
    struct RequestMessage: Encodable, Sendable { var role: String; var content: String }
}

struct ChatCompletionResponse: Decodable, Sendable {
    var id: String?
    var choices: [Choice]
    var sessionID: String?              // "session_id"
    struct Choice: Decodable, Sendable {
        var message: MessagePayload?
        struct MessagePayload: Decodable, Sendable { var role: String?; var content: String? }
        var finishReason: String?       // "finish_reason"
    }
}

struct ChatChunk: Decodable, Sendable { // one SSE "data:" payload
    var choices: [Choice]
    var sessionID: String?
    struct Choice: Decodable, Sendable {
        var delta: Delta?
        var finishReason: String?
        struct Delta: Decodable, Sendable { var role: String?; var content: String? }
    }
}
```

```swift
// SessionModels.swift
struct Session: Codable, Sendable, Identifiable, Hashable {
    var id: String
    var title: String?
    var model: String?
    var status: String?
    var messageCount: Int?              // "message_count"
    var createdAt: Date?                // "created_at"
    var updatedAt: Date?
}

struct SessionMessage: Codable, Sendable, Identifiable, Hashable {
    var id: String
    var role: MessageRole
    var content: String?
    var createdAt: Date?
    var toolCalls: [ToolCall]?          // "tool_calls"
    struct ToolCall: Codable, Sendable, Hashable { var name: String?; var arguments: String? }
}
```

```swift
// JobModels.swift
enum JobRunStatus: String, Codable, Sendable { case success, failed, running, never, unknown }

struct CronJob: Codable, Sendable, Identifiable, Hashable {
    var id: String
    var name: String
    var prompt: String
    var schedule: String                // cron expression, e.g. "0 9 * * *"
    var enabled: Bool
    var lastRunAt: Date?
    var nextRunAt: Date?
    var lastStatus: JobRunStatus?
    var createdAt: Date?
}

struct UpsertJobRequest: Encodable, Sendable {   // used for both POST and PATCH
    var name: String
    var prompt: String
    var schedule: String
    var enabled: Bool
}
```

```swift
// StatusModels.swift
struct HealthStatus: Codable, Sendable {
    var status: String?                 // "ok"
    var version: String?
    var uptimeSeconds: TimeInterval?    // "uptime_seconds"
    var model: String?
}

struct Skill: Codable, Sendable, Identifiable, Hashable {
    var id: String; var name: String?; var description: String?; var enabled: Bool?
}

struct Toolset: Codable, Sendable, Identifiable, Hashable {
    var id: String; var name: String?; var description: String?
    var tools: [Tool]?
    struct Tool: Codable, Sendable, Hashable { var name: String?; var description: String? }
}

struct Run: Codable, Sendable, Identifiable, Hashable {
    var id: String; var sessionID: String?; var status: String?
    var startedAt: Date?; var finishedAt: Date?
}
```

```swift
// ConfigModels.swift
enum JSONValue: Codable, Sendable, Hashable {   // dynamic config values
    case string(String), number(Double), bool(Bool), null
    // Custom Codable: try bool, then number, then string, else null.
}

struct AgentConfig: Sendable {
    var entries: [ConfigEntry]          // sorted by key for display
    struct ConfigEntry: Sendable, Identifiable, Hashable {
        var id: String { key }
        var key: String
        var value: JSONValue
    }
}
```

```swift
// ListResponse.swift — tolerant envelope (see §14 rule T1)
struct ListResponse<Element: Decodable>: Decodable { var data: [Element] }
struct ObjectResponse<Element: Decodable>: Decodable { var data: Element }
```

### 4.2 SwiftData cache models (`Models/Persistence/`)

```swift
@Model final class CachedSession {
    @Attribute(.unique) var id: String
    var title: String; var model: String; var status: String
    var messageCount: Int
    var createdAt: Date; var updatedAt: Date; var fetchedAt: Date
    @Relationship(deleteRule: .cascade, inverse: \CachedMessage.session)
    var messages: [CachedMessage] = []
    init(from dto: Session) { … }
}

@Model final class CachedMessage {
    var id: String; var role: String; var content: String
    var createdAt: Date; var toolCallsJSON: String?   // serialized [ToolCall]
    var session: CachedSession?
}

@Model final class CachedJob {
    @Attribute(.unique) var id: String
    var name: String; var prompt: String; var schedule: String
    var enabled: Bool; var lastStatus: String?
    var lastRunAt: Date?; var nextRunAt: Date?; var fetchedAt: Date
    init(from dto: CronJob) { … }
}

@Model final class CachedStatus {   // single-row snapshot store
    @Attribute(.unique) var key: String          // "health" | "skills" | "toolsets" | "runs" | "config"
    var json: Data                                // encoded DTO payload
    var fetchedAt: Date
}
```

Mapping helpers live on the cache models: `init(from:)` DTO→cache and `func toDTO()` cache→DTO.

---

## 5. Networking Layer

### 5.1 `Endpoint` (Networking/Endpoint.swift)

```swift
enum Endpoint: Sendable {
    case health
    case chatCompletions
    case runs
    case sessions, session(id: String), sessionMessages(id: String), forkSession(id: String)
    case jobs, job(id: String), pauseJob(id: String), resumeJob(id: String), runJob(id: String)
    case skills, toolsets
    case config

    var method: String  // "GET" | "POST" | "PATCH" | "DELETE"
    var path: String    // e.g. "/api/jobs/job_42/pause"
}
```

### 5.2 Client protocol (Networking/HermesAPIClient.swift)

```swift
protocol HermesAPIClient: Sendable {
    func health() async throws -> HealthStatus

    func chat(_ request: ChatCompletionRequest) async throws -> ChatCompletionResponse
    func streamChat(_ request: ChatCompletionRequest) -> AsyncThrowingStream<ChatStreamEvent, Error>

    func listRuns() async throws -> [Run]

    func listSessions() async throws -> [Session]
    func sessionMessages(_ sessionID: String) async throws -> [SessionMessage]
    func forkSession(_ sessionID: String) async throws -> Session
    func deleteSession(_ sessionID: String) async throws

    func listJobs() async throws -> [CronJob]
    func createJob(_ body: UpsertJobRequest) async throws -> CronJob
    func updateJob(_ id: String, _ body: UpsertJobRequest) async throws -> CronJob
    func pauseJob(_ id: String) async throws -> CronJob
    func resumeJob(_ id: String) async throws -> CronJob
    func runJobNow(_ id: String) async throws
    func deleteJob(_ id: String) async throws

    func listSkills() async throws -> [Skill]
    func listToolsets() async throws -> [Toolset]

    func getConfig() async throws -> AgentConfig
    func updateConfig(_ changes: [String: JSONValue]) async throws -> AgentConfig
}

enum ChatStreamEvent: Sendable {
    case token(String)          // incremental text
    case sessionID(String)      // server-assigned session (first chunk carrying it)
    case finished(reason: String?)
}
```

### 5.3 Live implementation (Networking/LiveHermesAPIClient.swift)

`final class LiveHermesAPIClient: HermesAPIClient, @unchecked Sendable` (immutable after init → safe).

- **Inputs:** `serverURL: String`, `apiKeyProvider: @Sendable () -> String?` (reads Keychain), injected `URLSession`.
- **URLSession config:** `timeoutIntervalForRequest = 15`, `timeoutIntervalForResource = 300` (SSE), `waitsForConnectivity = false`.
- **Request building:** `<serverURL>` trimmed of trailing `/` + endpoint path. Headers: `Authorization: Bearer …`, `Content-Type`/`Accept`. Missing key → throw `.notConfigured` before any network call.
- **Generic core (private):**
  ```swift
  func send<Body: Encodable, Output: Decodable>(
      _ endpoint: Endpoint, body: Body?, acceptableStatus: Range<Int> = 200..<300
  ) async throws -> Output
  ```
  - Encodes body with `JSONEncoder` (`.convertToSnakeCase` **not** used — DTOs carry explicit `CodingKeys`).
  - On non-2xx: try to decode the error envelope → map to `APIError` (§9).
  - Decodes with shared `JSONDecoder.hermes` (ISO-8601 with fractional-seconds fallback; tolerant envelope unwrap per §14).
  - `204` responses: a `sendVoid(_:)` variant that skips decoding.
- **SSE (`streamChat`):**
  ```swift
  func streamChat(_ request: ChatCompletionRequest) -> AsyncThrowingStream<ChatStreamEvent, Error> {
      AsyncThrowingStream { continuation in
          let task = Task {
              do {
                  var req = request; req.stream = true
                  let urlRequest = try buildRequest(.chatCompletions, body: req,
                                                    accept: "text/event-stream")
                  let (bytes, response) = try await session.bytes(for: urlRequest)
                  try validate(response)
                  for try await line in bytes.lines {
                      if Task.isCancelled { break }
                      switch SSEParser.parse(line: line) {
                      case .data(let payload):
                          if payload == "[DONE]" { continuation.yield(.finished(reason: nil)); continuation.finish(); return }
                          let chunk = try decoder.decode(ChatChunk.self, from: Data(payload.utf8))
                          if let sid = chunk.sessionID { continuation.yield(.sessionID(sid)) }
                          if let text = chunk.choices.first?.delta?.content, !text.isEmpty {
                              continuation.yield(.token(text))
                          }
                          if let reason = chunk.choices.first?.finishReason {
                              continuation.yield(.finished(reason: reason))
                          }
                      case .ignored: continue
                      }
                  }
                  continuation.finish()
              } catch {
                  continuation.finish(throwing: APIError.from(error))
              }
          }
          continuation.onTermination = { _ in task.cancel() }
      }
  }
  ```

### 5.4 SSE parsing (Networking/SSEParser.swift)

Line-oriented stateless parser — `URLSession.AsyncBytes.lines` already splits on `\n` and handles `\r\n`:

```swift
enum SSELine: Sendable { case data(String), ignored }
enum SSEParser {
    static func parse(line: String) -> SSELine {
        if line.hasPrefix("data:") {
            return .data(String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces))
        }
        return .ignored   // blank separators, "event:", "id:", ":comment" heartbeats
    }
}
```

Multi-line `data:` concatenation is intentionally not implemented (Hermes emits single-line JSON events); document this assumption.

### 5.5 Connectivity monitor (Networking/ConnectivityMonitor.swift)

```swift
@Observable final class ConnectivityMonitor {
    private(set) var isOnline: Bool = true
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "connectivity")
    func start() { monitor.pathUpdateHandler = { [weak self] path in
        Task { @MainActor in self?.isOnline = (path.status == .satisfied) }
    }; monitor.start(queue: queue) }
    func stop() { monitor.cancel() }
}
```

This tracks **device** connectivity. **Server** reachability is tracked separately via `ConnectionState` in `AppState` (§6.1) — Tailscale traffic arrives over a `utun` interface that NWPathMonitor reports as `.satisfied` only when the VPN is up, which is exactly the failure we want to surface ("Enable Tailscale").

### 5.6 Mock client (Networking/MockHermesAPIClient.swift)

`final class MockHermesAPIClient: HermesAPIClient` with canned responses, configurable latency/failures, and a scripted `streamChat` that yields tokens with 30 ms delays. Used by SwiftUI `#Preview`s and unit tests. Not shipped in release UI.

---

## 6. State Management

### 6.1 Root state — AppState (App/AppState.swift)

Single `@Observable` root object, created in `HermesApp.init`, injected with `.environment(appState)`. Also acts as the **DI container / ViewModel factory**.

```swift
enum AppTab: Hashable { case chat, sessions, jobs, status, settings }

enum ConnectionState: Equatable {
    case unknown, checking
    case connected(version: String)
    case unreachable(reason: String)
    case unauthorized
}

@MainActor @Observable
final class AppState {
    // Published UI state
    var selectedTab: AppTab = .chat
    var connectionState: ConnectionState = .unknown
    var isConfigured: Bool { settings.hasServerURL && keychain.hasAPIKey }

    // Services (let — never reassign)
    let settings: SettingsStore
    let keychain: KeychainStore
    let cache: CacheStore
    let connectivity: ConnectivityMonitor
    private(set) var api: HermesAPIClient   // rebuilt when server URL changes

    init() { … }                            // wires everything; starts connectivity monitor

    func rebuildClient()                    // called after settings change
    func checkConnection() async            // GET /health → connectionState
    func signOut()                          // wipe key + cache → isConfigured false

    // Factories
    func makeChatViewModel() -> ChatViewModel
    func makeSessionsViewModel() -> SessionsViewModel
    func makeSessionDetailViewModel(_ session: Session) -> SessionDetailViewModel
    func makeJobsViewModel() -> JobsViewModel
    func makeJobFormViewModel(editing job: CronJob?) -> JobFormViewModel
    func makeStatusViewModel() -> StatusViewModel
    func makeSettingsViewModel() -> SettingsViewModel
}
```

### 6.2 ViewModel pattern

Every screen has exactly one `@MainActor @Observable final class` ViewModel, created once per view via `@State`:

```swift
struct SessionsListView: View {
    @Environment(AppState.self) private var appState
    @State private var vm: SessionsViewModel?
    var body: some View {
        Group { if let vm { content(vm) } else { ProgressView() } }
            .task { if vm == nil { vm = appState.makeSessionsViewModel(); await vm?.load() } }
    }
}
```

Standard ViewModel shape:

```swift
@MainActor @Observable
final class JobsViewModel {
    private(set) var state: LoadState<[CronJob]> = .idle
    var isStale = false                     // data came from cache
    private let api: HermesAPIClient
    private let cache: CacheStore
    private let connectivity: ConnectivityMonitor

    func load() async                       // network → state + cache write-through; fallback cache
    func refresh() async                    // pull-to-refresh (same as load, keeps old data visible)
    func pause(_ job: CronJob) async
    func resume(_ job: CronJob) async
    func runNow(_ job: CronJob) async
    func delete(_ job: CronJob) async
    // mutations: optimistic-disabled while offline; on success update `state` in place
}
```

### 6.3 LoadState (Utilities/LoadState.swift)

```swift
enum LoadState<Value> {
    case idle
    case loading
    case loaded(Value)
    case failed(APIError)

    var value: Value? { if case .loaded(let v) = self { v } else { nil } }
}
```

Full-screen content uses `LoadStateView` (Views/Components) to switch: `idle/loading → LoadingView`, `failed → ErrorStateView(retry)`, `loaded(empty) → EmptyStateView`, `loaded → content`.

### 6.4 Chat streaming state (ViewModels/ChatViewModel.swift)

```swift
@MainActor @Observable
final class ChatViewModel {
    private(set) var messages: [ChatMessage] = []
    var input = ""
    private(set) var isStreaming = false
    private(set) var error: APIError?
    private(set) var sessionID: String?     // nil = new conversation
    private var streamTask: Task<Void, Never>?

    func send()            // appends user ChatMessage + empty streaming assistant message,
                           // consumes streamChat, appends tokens to last message,
                           // captures sessionID event, handles .finished / errors
    func cancelStreaming() // streamTask?.cancel(); marks last message complete
    func newChat()         // clears messages + sessionID
    func continueSession(_ session: Session)  // loads history, sets sessionID (from Sessions tab)
}
```

`send()` core loop:
```swift
streamTask = Task {
    do {
        for try await event in api.streamChat(request) {
            switch event {
            case .token(let t):        messages[lastIdx].content += t
            case .sessionID(let sid):  sessionID = sid
            case .finished:            messages[lastIdx].isStreaming = false
            }
        }
    } catch is CancellationError { /* user cancelled */ }
    catch { self.error = APIError.from(error); messages[lastIdx].isStreaming = false }
    isStreaming = false
}
```

### 6.5 Data ownership summary

| State | Owner | Backing |
|---|---|---|
| Selected tab, connection state | `AppState` (`@Observable`) | memory |
| Server URL, theme, has-onboarded | `SettingsStore` (`@Observable`) | UserDefaults |
| API key | `KeychainStore` | Keychain |
| Screen data (lists, details) | per-screen ViewModel | network + SwiftData cache |
| Offline cache | `CacheStore` | SwiftData `ModelContainer` |
| Device connectivity | `ConnectivityMonitor` | NWPathMonitor |

---

## 7. Navigation & View Hierarchy

### 7.1 Root structure

```
HermesApp (@main)
└── WindowGroup
    └── ContentView                       // root gate
        ├── if !appState.isConfigured ──▶ SetupView
        └── else ──▶ TabView(selection: appState.selectedTab)
            ├── Tab 1 "Chat"     (bubble.left.and.bubble.right) → NavigationStack { ChatView }
            ├── Tab 2 "Sessions" (clock.arrow.circlepath)       → NavigationStack { SessionsListView }
            │     └── push: SessionDetailView
            ├── Tab 3 "Jobs"     (calendar.badge.clock)         → NavigationStack { JobsListView }
            │     ├── push: JobDetailView
            │     └── sheet: JobFormView (create / edit)
            ├── Tab 4 "Status"   (heart.text.square)            → NavigationStack { StatusDashboardView }
            │     ├── push: SkillsListView
            │     ├── push: ToolsetsListView
            │     ├── push: RunsListView
            │     └── sheet: ConfigEditView
            └── Tab 5 "Settings" (gearshape)                    → NavigationStack { SettingsView }
```

### 7.2 Navigation rules

- Each tab owns an **independent `NavigationStack`** (no shared path — tabs are shallow; use typed `.navigationDestination(for:)` where a path is needed, e.g. Sessions).
- Create/edit flows are **sheets** (`JobFormView`, `ConfigEditView`). Detail flows are **pushes**.
- Destructive actions (delete session/job, sign out) use `confirmationDialog`.
- Cross-tab navigation only via `appState.selectedTab` (e.g. "Continue in Chat" from a session sets `chatVM.continueSession(...)` then `selectedTab = .chat`). The Chat tab's ViewModel therefore lives in `AppState` (one shared instance), not per-view: `appState.chatViewModel`.
- All alerts/errors presented via a shared `.alert(item:)` modifier bound to the ViewModel's `error` (§9.3).
- Offline: `OfflineBannerView` pinned above tab content when `!connectivity.isOnline` or `connectionState == .unreachable`.

### 7.3 Screen specifications

**SetupView** (onboarding gate)
- Fields: server URL (`TextField`, keyboard `.URL`, autocap off), API key (`SecureField`).
- "Connect" button → `SettingsViewModel.connect()` → `health()` → on success persist + dismiss; on failure inline error text.
- Helper text: how to find the Tailscale IP (`tailscale ip -4`) and that Tailscale must be running on both devices.

**ChatView**
- `List`/inverted `ScrollView` of `MessageBubbleView` (role-colored, assistant left / user right, monospaced tool messages), auto-scroll to bottom on new token.
- Bottom `ChatInputBar`: multiline `TextField`, Send button (disabled while `input` blank or `isStreaming`), becomes Stop button while streaming.
- Toolbar: "New Chat" (`plus`), current session id subtitle. Streaming indicator (`…` bubble) while awaiting first token.
- Empty state: "Ask Hermes anything."

**SessionsListView**
- `List` of `SessionRowView` (title, relative `updatedAt`, message count badge, status dot).
- Pull-to-refresh, `.searchable` on title, swipe-to-delete (confirmation), toolbar sort (recent/oldest).
- LoadState-driven full states: loading / error+retry / empty ("No sessions yet").

**SessionDetailView**
- Header: title, model, created/updated, message count.
- Message list (read-only `MessageBubbleView`s, tool calls rendered collapsible).
- Toolbar menu: **Fork** (creates copy → navigates to it), **Continue in Chat** (§7.2), **Delete**.

**JobsListView**
- `List` with two sections: **Active** / **Paused** (derived from `enabled`).
- `JobRowView`: name, cron schedule + human hint (show raw expression verbatim; no cron parser — optional static presets only in form), `Toggle` bound to pause/resume, last status icon (✓ green / ✗ red / spinner / –).
- Swipe actions: Run Now (tint), Delete (destructive). Toolbar `+` → `JobFormView` sheet.
- Pull-to-refresh; LoadState full states.

**JobDetailView**
- Form layout: name, schedule, prompt (multiline), enabled toggle, last/next run times, last status.
- Buttons: Run Now, Edit (sheet `JobFormView(editing:)`), Delete (confirmation).

**JobFormView** (sheet, create + edit)
- Fields: Name, Prompt (multiline `TextEditor`, min 3 lines), Schedule (text field + preset picker: Hourly / Daily 9:00 / Weekdays 9:00 / Custom → fills expression), Enabled toggle.
- Validation: all fields non-empty; schedule must be 5 whitespace-separated fields → inline error otherwise (no full cron validation).
- Save → `createJob`/`updateJob` → dismiss on success; error shown in-sheet.

**StatusDashboardView**
- `List` of sections, all refreshed by single `StatusViewModel.load()` + pull-to-refresh:
  1. **Health** (`HealthCardView`): status dot (green `ok`), version, uptime (formatted `1d 4h`), model, connection state.
  2. **Skills**: count row → push `SkillsListView` (name, description, enabled badge).
  3. **Toolsets**: count row → push `ToolsetsListView` (sections per toolset, rows per tool).
  4. **Recent Runs**: count row → push `RunsListView` (status, session id, started, duration).
  5. **Configuration**: key/value rows (booleans as toggles-bound text, numbers as-is) + "Edit" → `ConfigEditView` sheet (string/number/bool editor per entry, PATCH on save).

**SettingsView**
- Section *Connection*: server URL field, API key `SecureField` (shows masked placeholder when set), **Test Connection** button with result label, "How to connect" footer text.
- Section *Appearance*: theme picker — System / Light / Dark (§11).
- Section *Data*: Clear Cache (confirmation, purges SwiftData).
- Section *About*: app version, Hermes server version (from last health check).
- **Sign Out** (destructive, confirmation) → wipes API key + cache → returns to `SetupView`.

### 7.4 Shared components (Views/Components/)

| Component | Signature/notes |
|---|---|
| `LoadingView` | `ProgressView` + label |
| `EmptyStateView` | SF Symbol + title + subtitle |
| `ErrorStateView` | icon + message + Retry button |
| `OfflineBannerView` | orange banner: "No connection — showing cached data" |
| `LoadStateView<Value,Content>` | generic switch over `LoadState` (§6.3) |

---

## 8. Auth Flow & Security

### 8.1 Auth state machine

```
Launch
  │
  ▼
isConfigured?  (serverURL set in UserDefaults AND apiKey present in Keychain)
  │ no                          │ yes
  ▼                             ▼
SetupView ◀──signOut── checkConnection() (GET /health, 10 s timeout)
  │ Connect tapped              │
  │                             ├─ 200 → .connected(version) → TabView fully enabled
  ├─ health() OK → persist URL (UserDefaults) + key (Keychain)
  │      → isConfigured → TabView
  │                             ├─ 401 → .unauthorized → banner "API key rejected"
  │                             │        + badge on Settings tab → user re-enters key
  ├─ fail → inline error, stay  └─ timeout/URLError → .unreachable(reason)
         on SetupView                    → OfflineBanner "Can't reach Hermes — check Tailscale"
                                         → auto-retry health every 30 s while app active
```

- `AppState.checkConnection()` is the only place that mutates `connectionState`.
- Any API call receiving `401` calls `appState.checkConnection()` (which re-probes and lands on `.unauthorized`); it never wipes the key automatically.
- **Sign Out** deletes the Keychain item and purges the cache; UserDefaults URL is kept to make re-onboarding one field shorter (documented behavior).

### 8.2 Keychain (Services/KeychainStore.swift)

```swift
final class KeychainStore: Sendable {
    static let service = "com.hermes.ios.apikey"
    private let account = "hermes-api-key"

    var hasAPIKey: Bool { (try? read()) != nil }
    func save(_ key: String) throws    // kSecClassGenericPassword, upsert (SecItemAdd → SecItemUpdate)
    func read() throws -> String?      // kSecReturnData, UTF-8
    func delete() throws
}
```

- Accessibility: `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` (works with background refresh; never synced to iCloud).
- No access groups / keychain sharing (single app).
- Errors wrapped in `APIError.keychain(status:)` for diagnostics.

### 8.3 Transport security

- The link is HTTP **inside** the WireGuard-encrypted Tailscale tunnel — plaintext at the HTTP layer, encrypted on the wire. No TLS termination on the Hermes gateway is assumed.
- **ATS:** raw-IP `http://` URLs require an exception. `Info.plist`:
  ```xml
  <key>NSAppTransportSecurity</key>
  <dict>
      <key>NSAllowsArbitraryLoads</key><true/>
  </dict>
  ```
  with a code comment justifying it (private tailnet, CGNAT `100.64.0.0/10`, user-supplied host only). The URL field is restricted to `http`/`https`; if the user enters `https://` it is used as-is (future-proofing for a TLS-enabled gateway).
- The API key is **never** logged (OSLog interpolations use `%{private}@` or omit it), never shown outside `SecureField`, never written to SwiftData/UserDefaults.

### 8.4 Tailscale connectivity (user-facing)

- Server host is manual (no discovery — Tailscale IPs are stable; Bonjour doesn't cross the tailnet).
- Settings + Setup both show: "Find the PC's IP: run `tailscale ip -4` on the Windows PC, or check the Tailscale admin console. Tailscale must be ON on this iPhone."
- `.unreachable` error copy always suggests, in order: Tailscale on iPhone → Tailscale on PC → Hermes service running → correct IP/port.

---

## 9. Error Handling

### 9.1 Error type (Utilities/APIError.swift)

```swift
enum APIError: LocalizedError, Equatable {
    case notConfigured
    case invalidURL(String)
    case unauthorized                       // 401
    case forbidden                          // 403
    case notFound(resource: String)         // 404
    case conflict(message: String)          // 409
    case server(status: Int, message: String)   // other 4xx/5xx, message from error envelope
    case decoding(detail: String)           // JSON mismatch
    case offline                            // device known-offline (pre-flight check)
    case unreachable(detail: String)        // URLError: cannotConnect/host/timeout/DNS
    case streamInterrupted
    case keychain(status: OSStatus)
    case cancelled
    case unknown(detail: String)

    var errorDescription: String?          // user-facing one-liner per case
    var recoverySuggestion: String?        // e.g. "Check that Tailscale is connected…"
}
```

### 9.2 Mapping

`static func from(_ error: Error) -> APIError`:
- already `APIError` → passthrough
- `CancellationError` / `URLError.cancelled` → `.cancelled`
- `URLError` codes `.notConnectedToInternet` → `.offline`; `.cannotConnectToHost`, `.cannotFindHost`, `.timedOut`, `.networkConnectionLost`, `.dnsLookupFailed` → `.unreachable(detail)`
- `DecodingError` → `.decoding` with key path context
- fallback → `.unknown`

HTTP status mapping (after decoding error envelope for `message`): `401→.unauthorized`, `403→.forbidden`, `404→.notFound`, `409→.conflict`, else `.server(status:message)`.

### 9.3 Presentation rules

| Context | UX |
|---|---|
| Full-screen load failure | `ErrorStateView` with message + **Retry** |
| Pull-to-refresh failure | keep old data + transient banner/toast |
| Mutation failure (delete/pause/create) | `.alert(item: $vm.error)` with OK; form sheets show inline error, stay open |
| Chat stream failure | inline error bubble under the partial message + "Retry" re-sends last user message |
| 401 anywhere | global banner + Settings badge (§8.1) |
| `.cancelled` | never shown |
| Offline device | mutations disabled at the button level; no error dialogs for pre-flight `.offline` |

All user strings come from `APIError.errorDescription` (+ `recoverySuggestion` as alert body). Diagnostics go to `Logger(subsystem: "com.hermes.ios", category: "network")`.

---

## 10. Offline Support & Persistence

### 10.1 Strategy

**Cache-as-fallback with write-through**, per feature:

| Data | Cached | Offline behavior |
|---|---|---|
| Sessions list | ✓ `CachedSession` | browse cached, `isStale` banner |
| Session messages | ✓ `CachedMessage` (on detail open) | read cached history |
| Jobs list | ✓ `CachedJob` | browse cached; **all mutations disabled** |
| Status (health/skills/toolsets/runs/config) | ✓ `CachedStatus` JSON snapshots | show last snapshot + "as of …" timestamp |
| Chat | ✗ (transient) | input disabled with hint; no streaming offline |

### 10.2 Flow (per list screen)

```
load()
  │
  ├─ connectivity.isOnline == false ──▶ state = .loaded(cache.fetch…()) , isStale = true
  │
  └─ try network
        ├─ success → state = .loaded(dtos); cache.replaceAll(dtos); isStale = false
        └─ catch   → if cache non-empty: state = .loaded(cache), isStale = true
                     else:               state = .failed(mappedError)
```

### 10.3 CacheStore (Services/CacheStore.swift)

```swift
@MainActor final class CacheStore {
    let container: ModelContainer      // built in HermesApp.init, shared via AppState
    private var context: ModelContext { container.mainContext }

    func replaceSessions(_ dtos: [Session])            // delete-all + insert, single save()
    func cachedSessions() -> [Session]                 // sorted updatedAt desc
    func saveMessages(_ dtos: [SessionMessage], sessionID: String)
    func cachedMessages(sessionID: String) -> [SessionMessage]
    func replaceJobs(_ dtos: [CronJob])
    func cachedJobs() -> [CronJob]
    func saveSnapshot<T: Encodable>(_ value: T, key: String)   // CachedStatus upsert
    func snapshot<T: Decodable>(_ type: T.Type, key: String) -> (value: T, fetchedAt: Date)?
    func deleteSession(id: String)                     // also on server-delete success
    func clearAll()                                    // Settings → Clear Cache / Sign Out
}
```

- `ModelContainer` schema: `[CachedSession.self, CachedMessage.self, CachedJob.self, CachedStatus.self]`, default on-disk store. If container creation fails at launch → fall back to in-memory container (`isStoredInMemoryOnly: true`) and continue with caching disabled (log only, no crash).
- No background sync / no conflict resolution — server always wins; cache is read-only fallback.
- `fetchedAt` drives "Cached · 2h ago" labels.

---

## 11. Dark Mode & Theming

- **Native-first:** semantic colors everywhere — `Color.primary/.secondary`, `Color(.systemBackground)/(.secondarySystemBackground)`, `.tint`. No hardcoded whites/blacks. SF Symbols render automatically.
- **Chat bubbles:** user = `Color.accentColor` bg / white text; assistant = `Color(.secondarySystemBackground)` bg / `Color.primary` text — both adapt. Code/tool content: `Font.system(.body, design: .monospaced)` on `Color(.tertiarySystemBackground)`.
- **Accent:** single `AccentColor` in Assets (indigo suggested) with optional dark variant; status colors use `.green/.orange/.red` semantics.
- **Assets:** AppIcon + AccentColor only; any custom colors defined in asset catalog with Any/Dark appearances (no programmatic `UIColor(dynamicProvider:)`).
- **User override:** `SettingsStore.theme: AppTheme { case system, light, dark }` persisted in UserDefaults; applied once at root: `ContentView.preferredColorScheme(theme.colorScheme)` (nil for `.system`).
- Verify every screen in both appearances (Previews: `.preferredColorScheme(.dark)` variants on component previews).

---

## 12. Concurrency Rules

- **All ViewModels are `@MainActor`.** Never mutate view state off the main actor.
- `LiveHermesAPIClient` is `Sendable`, stateless beyond config — safe to call from any context.
- SSE iteration happens inside the ViewModel's `Task` (main-actor hops are implicit per `yield`/await; token volume is small — no batching needed).
- Every long operation keeps a `Task` handle: cancelled on `.onDisappear` (lists) or explicit Cancel (chat). URLSession tasks must observe cancellation (`bytes(for:)` throws on cancel — mapped to `.cancelled`, never surfaced).
- SwiftData: **main context only** (`@MainActor CacheStore`). No background model contexts.
- No `@Published`/Combine. No delegates. `NWPathMonitor` callback hops to MainActor immediately (§5.5).
- `Sendable` annotations on all DTOs; no `@unchecked Sendable` except the immutable client.

---

## 13. Project File Structure

Xcode target: `HermesApp`, iOS 17.0, no Swift packages. Files on disk:

```
HermesApp/
├── HermesApp.swift                     @main; builds ModelContainer + AppState; .environment injection
├── ContentView.swift                   root gate (Setup vs TabView); theme + offline banner
├── Info.plist                          ATS exception (§8.3), portrait orientations
├── Assets.xcassets/
│   ├── AppIcon.appiconset
│   └── AccentColor.colorset
│
├── App/
│   └── AppState.swift                  root @Observable + DI + factories + AppTab + ConnectionState
│
├── Models/
│   ├── ChatModels.swift                ChatMessage, ChatCompletionRequest/Response, ChatChunk, MessageRole
│   ├── SessionModels.swift             Session, SessionMessage
│   ├── JobModels.swift                 CronJob, UpsertJobRequest, JobRunStatus
│   ├── StatusModels.swift              HealthStatus, Skill, Toolset, Run
│   ├── ConfigModels.swift              JSONValue, AgentConfig
│   ├── ListResponse.swift              ListResponse/ObjectResponse envelopes + tolerant decoding helpers
│   └── Persistence/
│       ├── CachedSession.swift
│       ├── CachedMessage.swift
│       ├── CachedJob.swift
│       └── CachedStatus.swift
│
├── Networking/
│   ├── Endpoint.swift                  endpoint enum: path + method
│   ├── HermesAPIClient.swift           protocol + ChatStreamEvent
│   ├── LiveHermesAPIClient.swift       URLSession impl: request building, decode, error mapping, SSE
│   ├── SSEParser.swift                 line → SSELine
│   ├── ConnectivityMonitor.swift       NWPathMonitor wrapper
│   └── MockHermesAPIClient.swift       previews/tests
│
├── Services/
│   ├── SettingsStore.swift             @Observable; UserDefaults: serverURL, theme, onboarding flag
│   ├── KeychainStore.swift             API key CRUD (§8.2)
│   └── CacheStore.swift                SwiftData read/write (§10.3)
│
├── ViewModels/
│   ├── ChatViewModel.swift             streaming chat (§6.4)
│   ├── SessionsViewModel.swift         list + delete + search
│   ├── SessionDetailViewModel.swift    messages + fork + continue
│   ├── JobsViewModel.swift             list + pause/resume/run/delete
│   ├── JobFormViewModel.swift          create/edit validation
│   ├── StatusViewModel.swift           health/skills/toolsets/runs/config aggregate
│   └── SettingsViewModel.swift         connect/test/sign-out/clear-cache
│
├── Views/
│   ├── Setup/
│   │   └── SetupView.swift
│   ├── Chat/
│   │   ├── ChatView.swift
│   │   ├── MessageBubbleView.swift     reused read-only by SessionDetailView
│   │   └── ChatInputBar.swift
│   ├── Sessions/
│   │   ├── SessionsListView.swift
│   │   ├── SessionRowView.swift
│   │   └── SessionDetailView.swift
│   ├── Jobs/
│   │   ├── JobsListView.swift
│   │   ├── JobRowView.swift
│   │   ├── JobDetailView.swift
│   │   └── JobFormView.swift
│   ├── Status/
│   │   ├── StatusDashboardView.swift
│   │   ├── HealthCardView.swift
│   │   ├── SkillsListView.swift
│   │   ├── ToolsetsListView.swift
│   │   ├── RunsListView.swift
│   │   └── ConfigEditView.swift
│   ├── Settings/
│   │   └── SettingsView.swift
│   └── Components/
│       ├── LoadingView.swift
│       ├── EmptyStateView.swift
│       ├── ErrorStateView.swift
│       ├── OfflineBannerView.swift
│       └── LoadStateView.swift
│
└── Utilities/
    ├── APIError.swift                  §9
    ├── LoadState.swift                 §6.3
    ├── Constants.swift                 default port 8642, keychain service, timeouts
    └── Extensions/
        ├── JSONDecoder+Hermes.swift    ISO-8601 (+fractional) strategy, tolerant envelopes
        ├── Date+Relative.swift         "2h ago", uptime "1d 4h"
        └── View+ErrorAlert.swift       .alert(item: APIError) helper

HermesAppTests/                         (added by QA phase)
├── LiveHermesAPIClientTests.swift      URLProtocol-stubbed session
├── ModelDecodingTests.swift            JSON fixtures, tolerance rules
├── ViewModelTests.swift                state transitions with MockHermesAPIClient
└── KeychainStoreTests.swift
```

---

## 14. Tolerance Rules (server schema drift)

The coding agent must implement these so minor Hermes version differences don't break the app:

- **T1 — Envelopes:** every list/object decode first tries `{data: …}`, then falls back to the bare payload (`[...]` / `{...}`). Implement once in `JSONDecoder+Hermes`.
- **T2 — Optional fields:** every DTO property except IDs and the fields strictly needed for a form is optional. Missing dates/counts render as "—", never crash.
- **T3 — Unknown enums:** decode unknown raw values into `.unknown` cases (custom `init(from:)`), never throw.
- **T4 — Dates:** accept ISO-8601 with and without fractional seconds (`yyyy-MM-dd'T'HH:mm:ss[.SSS]XXXXX`); try both formatters.
- **T5 — Extra keys:** ignored by default (struct decoding), keep it that way.
- **T6 — SSE:** unknown event lines ignored; `[DONE]` always terminates; stream ending without `[DONE]` is a normal finish, not an error.
- **T7 — Error body:** if the error envelope doesn't decode, use `HTTP {status}` as the message.

---

## 15. Implementation Order (for the coding agent)

1. `Utilities/` (APIError, LoadState, Constants, extensions) → 2. `Models/` (DTOs + persistence) → 3. `Services/` (Keychain → Settings → Cache) → 4. `Networking/` (Endpoint → protocol → SSEParser → Live client → Monitor → Mock) → 5. `App/AppState` → 6. ViewModels → 7. Views (Components first, then per-tab, Setup last) → 8. `HermesApp.swift` + `ContentView.swift` wiring → 9. `Info.plist` ATS.

Every file must be complete and compilable — no stubs, no `TODO`s. Follow the signatures in this document verbatim unless a compiler error forces a deviation (document any deviation in a code comment).
