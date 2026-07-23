# Code Review — Hermes iOS App

## Summary

**Files reviewed**: 33 Swift files across Models, Networking, Utilities, Views, ViewModels, and the App entry point.

**Severity legend**: 🔴 Critical | 🟡 Warning | 🔵 Info

---

## 🔴 Critical Issues

### 1. Hardcoded API key in production code
**File**: `APITypes.swift:310-311`
**Severity**: 🔴 Critical
**Description**: `ServerConfig.default` contains a hardcoded API key `"hermes-ios-app-key-2026"`. This is a security vulnerability — the key is baked into the binary and can be extracted from the compiled app.
**Fix**: Remove the hardcoded default. `HermesClient` (init at line 10-11) and any code using `ServerConfig.default.apiKey` should fall back to Keychain instead.

### 2. Duplicate model definitions — conflicting type ambiguity
**Files**: `APITypes.swift` vs `ChatModels.swift`, `APITypes.swift` vs `SessionModels.swift`
**Severity**: 🔴 Critical
**Description**: Multiple types are defined in more than one file:
- `ChatMessage` — defined in `APITypes.swift:10` (with `String` role + computed `MessageRole`) AND in `ChatModels.swift:3` (with `MessageRole` enum directly). This will cause a compiler error: "Invalid redeclaration of 'ChatMessage'".
- `ChatCompletionRequest` — defined in `APITypes.swift:31` and `ChatModels.swift:20`.
- `ChatCompletionRequestMessage` — defined in `APITypes.swift:52` and `ChatModels.swift:33`.
- `ChatCompletionResponse` — defined in `APITypes.swift:57` and `ChatModels.swift:38`.
- `MessageRole` — defined in `APITypes.swift:3` (includes `.tool`) and `ChatModels.swift:14` (missing `.tool`).
- `Session` — defined in `APITypes.swift:207` (with `title`, `Date?` dates) and `SessionModels.swift:3` (with `name`, `String?` dates).
- `SessionMessage` — defined in `APITypes.swift:235` (with `sessionId`, `createdAt`) and `SessionModels.swift:35` (without `sessionId`, with `timestamp`).
- `HealthStatus` — defined in `APITypes.swift:249` (with `HealthDetails`) and `StatusModels.swift:3` (with `capabilities`, `uptimeFormatted`).

These conflicting definitions mean the project cannot compile without explicit module/struct disambiguation. All these types must be deduplicated into a single canonical definition per type.

### 3. `toggleJob` uses `UUID(uuidString:)` on non-UUID string IDs
**File**: `JobViewModel.swift:53`
**Severity**: 🔴 Critical
**Bug**: `guard let id = UUID(uuidString: job.id) else { return }` — `job.id` is a `String` from the API (likely a server-assigned ID like `"job_abc123"`), not a UUID. `UUID(uuidString:)` will return `nil` for any non-UUID string, causing `toggleJob` to silently do nothing.
**Fix**: Remove the UUID conversion entirely. `job.id` is already a `String` and can be passed directly.

### 4. `emptyState` in `ChatListView.swift` renders `ChatDetailView` inside itself — infinite recursion
**File**: `ChatListView.swift:55`
**Severity**: 🔴 Critical
**Bug**: The `emptyState` view includes `ChatDetailView(chatVM: chatVM)` at line 55. This means when there are no messages/sessions, the detail view is still rendered inside the empty state — and it contains its own input bar and message list, creating visual duplication and likely incorrect layout behavior.

---

## 🟡 Warnings

### 5. `ChatMessage.role` is `String` but `ChatCompletionRequestMessage` also uses `String` — consistent but fragile
**File**: `APITypes.swift:12, 53`
**Severity**: 🟡 Warning
**Description**: Both `ChatMessage.role` and `ChatCompletionRequestMessage.role` are `String`. This is consistent but bypasses compile-time safety. When constructing request messages in `APIClient.swift:81` (`$0.role.rawValue`), any mismatch between the `MessageRole` enum string and the API's expected role strings will only surface at runtime.

### 6. `APIClient.streamChatCompletion` uses wrong `ChatCompletionResponse` model for SSE parsing
**File**: `APIClient.swift:196`, `SSEParser.swift:43`
**Severity**: 🟡 Warning
**Bug**: Both files decode SSE chunks using the non-streaming `ChatCompletionResponse` model (from `ChatModels.swift:38`), which expects the top-level `choices` array with `message` — but SSE chunks use `delta`, not `message`. The `ChatModels` version has both `message` and `delta` on `ChatChoice`, so it works. But `APITypes.swift` version's `Choice` struct only has `message` (no `delta`), so decoders using that version would fail on streaming responses. Ensure the correct model is used.

### 7. `HermesClient.updateConfig` is a no-op
**File**: `HermesClient.swift:203-205`
**Severity**: 🟡 Warning
**Bug**: `func updateConfig(serverUrl: String, apiKey: String) { return }` — the method signature promises to update config but the body is empty. The struct is `let`-based and immutable after init, so this should either be removed or the properties should be made `var` with proper reinitialization.

### 8. `SessionDetailView` requires two different initializers depending on call site
**Files**: `SessionListView.swift:49` vs `SessionsListView.swift:96`
**Severity**: 🟡 Warning
**Description**: `SessionListView.swift` calls `SessionDetailView(sessionId:sessionName:)` (a `String`/`String` init). `SessionsListView.swift` calls `SessionDetailView(session:sessionsVM:chatVM:)` (a `Session`/`SessionsViewModel`/`ChatViewModel` init). These appear to be two different structs or two different initializers, but only one `SessionDetailView` struct exists (at `SessionDetailView.swift:3`) with the `String`/`String` init. The `SessionsListView` call will fail to compile unless `SessionDetailView` has an overload accepting `(Session, SessionsViewModel, ChatViewModel)` — which it doesn't.

### 9. `ChatListView` is not used in the tab navigator
**File**: `ContentView.swift:8-12` uses `ChatView`; `ChatListView.swift` is a dead file
**Severity**: 🟡 Warning
**Description**: `ChatListView` defines its own `ChatDetailView` integration and session picker, but `ContentView.swift` only references `ChatView`. `ChatListView` is dead code — either it should replace `ChatView` or be removed.

### 10. `ChatView` uses `ChatBubbleView` referencing `APITypes.ChatMessage` — but `message.role` is `String`, not `MessageRole`
**File**: `ChatBubble.swift:8`
**Severity**: 🟡 Warning
**Description**: `ChatBubbleView` accesses `message.role == .assistant` and `message.role == .user` — this only compiles if `ChatMessage` is the `ChatModels.swift` version (where `role` is `MessageRole`). If `ChatMessage` resolves to the `APITypes.swift` version (where `role` is `String`), this code will fail. This ambiguity is another symptom of the duplicate-type problem (#2).

### 11. `EmptyBody` duplicated across files
**Files**: `HermesClient.swift:201`, `JobViewModel.swift:98`
**Severity**: 🟡 Warning
**Description**: `struct EmptyBody: Codable {}` is defined in both `HermesClient` (for `runStream`) and `JobViewModel` (for `runJobNow`). These will conflict at compile time.

---

## 🔵 Info / Best Practices

### 12. `@State private var viewModel = ChatViewModel()` should be `@State` for structs or `@Environment` for shared state
**File**: `ChatView.swift:4`, `StatusView.swift:4`, `SessionListView.swift:4`, `JobListView.swift:4`
**Description**: ViewModels marked `@Observable` are classes, but `@State` in SwiftUI is designed for value types. Using `@State` with a class creates a reference that SwiftUI won't properly observe for property changes. These should use `@StateObject` (iOS 16) or a plain `let`/`var` with observation from the parent. The `@Observable` macro in iOS 17+ handles this differently — `@State` *does* work with `@Observable` classes in iOS 17+ — so this may be intentional. Ensure deployment target is iOS 17+.

### 13. `SettingsViewModel` has a dead `isTestingConnection` / `testConnection()` method
**File**: `SettingsViewModel.swift:15, 44-58`
**Description**: `testConnection()` is defined but never called from `SettingsView.swift`. The Settings view calls `saveConfig()` which isn't defined — `SettingsView.swift:55` calls `settingsVM.saveConfig()` but the ViewModel only has `saveSettings()`. This will not compile.

### 14. `SettingsView` framework mismatch — uses `@State` but `SettingsViewModel` has different API than expected
**File**: `SettingsView.swift:4`
**Description**: `SettingsView` declares `@State var settingsVM: SettingsViewModel` and references properties like `settingsVM.serverUrl`, `settingsVM.apiKey`, `settingsVM.model`, `settingsVM.isLoading`, `settingsVM.saveSuccess`, `settingsVM.errorMessage`, `settingsVM.hasSavedConfig`, `settingsVM.loadFromKeychain()`, `settingsVM.saveConfig()`, `settingsVM.clearKeychain()`, `settingsVM.savedServerUrl`, `settingsVM.savedApiKeyMask`. However, `SettingsViewModel` defines `serverURL` (not `serverUrl`), no `model`, no `isLoading`, no `saveSuccess`, no `hasSavedConfig`, no `loadFromKeychain()`, no `saveConfig()`, no `clearKeychain()`, no `savedServerUrl`, no `savedApiKeyMask`. This is a complete API mismatch — the View will not compile against this ViewModel.

### 15. `SessionListView.SessionRowView` uses `updated.displayFormatted` on `String?`
**File**: `SessionListView.swift:77`
**Description**: `displayFormatted` is defined as a `String` extension that calls `self.parsedISO` (which expects a valid ISO date string). If the server returns dates in a different format, this will silently fall through and return the raw string. The `Session` model in `SessionModels.swift:6` uses `String?` for dates rather than `Date?`.

### 16. `SessionRow` in `SessionsListView.swift:147` uses `date, style: .relative` on `String?`
**File**: `SessionsListView.swift:148`
**Description**: `Text(date, style: .relative)` requires `Date`, but `session.updatedAt` and `session.createdAt` are `String?` in the `SessionModels` definition. This will not compile. The `Session` from `APITypes.swift` uses `Date?` which would work, but the file imports the `SessionModels.swift` `Session` type due to the duplicate definition issue.

### 17. SSE streaming in `APIClient` has fragile line buffering
**File**: `APIClient.swift:107-124`
**Description**: The implementation concatenates all `data:` lines into a single `buffer` string and only yields after an empty line. But for SSE streams, each `data:` line is typically a complete JSON chunk. If the server sends `data: {"choices":[{"delta":{"content":"Hello"}}]}\n\n`, the code would need an empty line after each chunk, which is standard SSE, so this likely works — but the buffer accumulation could concatenate multiple chunks if the server batch-sends them.

### 18. `NSAllowsLocalNetworking` in Info.plist only allows localhost, not Tailscale MagicDNS
**File**: `Info.plist:38`
**Description**: `NSAllowsLocalNetworking` only covers `localhost` and `*.local`. The Tailscale IP `100.115.248.107` is a public IP (RFC 6598 CGNAT range). For Tailscale to work with HTTP, the app needs either `NSAllowsArbitraryLoads` or a per-domain exception in `NSExceptionDomains`.
