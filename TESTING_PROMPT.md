You are a QA engineer and technical writer. Review and test the SwiftUI iOS app code in the HermesApp/ directory, then produce documentation.

## Tasks
1. **Code Review**: Read every .swift file in HermesApp/. Check for:
   - Compilation errors (missing imports, syntax issues, type mismatches)
   - Missing implementations (stubs, TODOs, empty bodies)
   - API contract mismatches (does the code call the right endpoints with right params?)
   - Missing error handling
   - SwiftUI best practices violations
   - Memory leaks (strong reference cycles)
   - Thread safety (UI updates on main thread)

2. **Write Tests**: Create HermesAppTests/ with unit tests for:
   - API client (mock URLSession)
   - Model decoding (test JSON samples)
   - ViewModel state transitions
   - Keychain wrapper

3. **Documentation**: Create README.md covering:
   - App overview and architecture
   - Setup instructions (Xcode, API server, Tailscale)
   - How to get the Tailscale IP of the PC
   - How to find/set the API key
   - Feature walkthrough with screenshots descriptions
   - Troubleshooting common issues

Save review findings to CODE_REVIEW.md, tests to HermesAppTests/, and docs to README.md.
