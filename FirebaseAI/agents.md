# Firebase AI SDK - Agent Workflow Instructions

The goal of this document is to ensure high-quality, reproducible, and verifiable contributions in a fully autonomous loop.

---

## 📥 Input Requirements

Before starting any work, the agent must require or acquire:
1.  **Feature Specification**: An OpenAPI specification, a link to the public docs for the feature, a snippet of the
    proto changes, a detailed natural language description of the feature, a PR pointing to another implementation
    on another platform, or some combination of them.
2.  **Project Configuration**: Use the `firebase-test-configs` skill to fetch the appropriate `GoogleService-Info.plist`
    for the target Firebase project. Do NOT proceed with integration tests without this.
3.  **Test Data**: Run `./scripts/update_vertexai_responses.sh` to clone the shared test data repository
    (`vertexai-sdk-test-data`) into `FirebaseAI/Tests/Unit/`.

## 📤 Output Requirements

A successful task completion MUST produce:
1.  **Code Changes**: The implemented feature and corresponding tests.
2.  **Unit & Integration Tests**: Demonstrating success and handling edge cases.
3.  **UI Tests (XCUITests)**: A physical or simulated demonstration of the feature.
4.  **Network Traces**: Real request and response bodies saved for validation.
5.  **`FirebaseAI/behaviours/`**: Updated documentation of API behaviors (create a file named after the feature,
    e.g., `search_grounding.md`).
6.  **Walkthrough Artifact**: A summary containing video evidence, network calls, and reproduction snippets.

---

## 🔄 The Agentic Loop: Step-by-Step

### Step 1: Endpoint Investigation & Diffing
- **Action**: Test the live endpoints for both **Google AI (Developer API)** and **Vertex AI** (Always via the Firebase
  proxy, never directly). Ensure that basic cases and edge cases are covered.
- **Goal**: Identify any differences in request/response schemas or behaviors between the two backends.
- **Handling**: Document these differences in a new file in the `FirebaseAI/behaviours/` directory (named after the
  feature) and implement strategy patterns or conditional handling in code to abstract these differences.

### Step 2: Test-Driven Development (TDD)
- **Constraint**: You MUST write tests before writing implementation code.
- **Unit Tests**:
    1. Write a failing unit test asserting the new behavior, following existing patterns in that test file if it exists.
    2. Mock network calls using `MockURLProtocol` or by providing fake responses.
- **Integration Tests**:
    1. Write tests that make real network calls to the live endpoints.
    2. **Network Traces**: During the first successful run of integration tests, capture the *actual* JSON request and
       response bodies.
    3. **Update Test Data**: Save these traces into `FirebaseAI/Tests/Unit/vertexai-sdk-test-data/mock-responses/`
       under a folder named after the feature. Use them to update unit test mocks.
    4. **Persist Changes**: To share these traces across platforms, contribute them to the
       `https://github.com/FirebaseExtended/vertexai-sdk-test-data` repository.

### Step 3: Implementation
- Follow `docs/firebase-api-guidelines.md`.
- Prioritize Swift concurrency (`async/await`) and ensure types are `Sendable` where applicable.

### Step 4: Public API Visibility
- **Requirement**: Identify and report any new public APIs created.
- **Method**: Run a git diff focusing on the `public` keyword in `FirebaseAI/Sources/` (this is a near-term
  solution).
- **Reporting**: List all new public methods, classes, and structs in the final Walkthrough artifact.

### Step 5: Test App & XCUITests
- **Action**: Add a demonstration of the new feature to the Test App located at `FirebaseAI/Tests/TestApp`.
- **UI Tests**: Write XCUITests in the Test App that exercise this UI.
- **Verification**: Ensure the tests pass on the latest iOS simulator.

### Step 6: Video Recording
- **Action**: Record a video of the XCUITests running.
- **Tool**: Exclusively use the `ios-simulator-test-recording` skill. Do not use the underlying scripts directly.
- **Output**: Save the video artifact and link it in the final walkthrough.

---

## 🏆 Quality Gates & Best Practices

To ensure "rock solid" quality, the agent must check:
- **Error Handling**: Do not just test happy paths. Write tests for rate limits, invalid JSON, and missing fields.
- **Code Style**: Run `./scripts/style.sh FirebaseAI/Sources/` and `./scripts/style.sh FirebaseAI/Tests/` before
  completing the task.
- **No Hardcoded Secrets**: Ensure no API keys or project IDs are committed. Use environment variables or the
  configuration skill.
- **Documentation**: Document any tricky edge cases or platform-specific behaviors in a file in the
  `FirebaseAI/behaviours/` directory.

---

## ✅ Pre-Commit Checklist
Take this list and ensure all work is complete before creating a new commit:
- [ ] **Endpoint Investigation**: Verified live endpoints (Google AI and Vertex AI via proxy) and documented
  differences in the `FirebaseAI/behaviours/` directory.
- [ ] **Unit Tests**: Passed all unit tests. Mock data is derived from real network traces.
- [ ] **Integration Tests**: Passed all integration tests against live endpoints.
- [ ] **Network Traces**: Captured and saved real request/response JSON payloads. **Ensure project names and API keys
  are obfuscated.**
- [ ] **Test App & UI Tests**: Added feature to Test App and passed XCUITests.
- [ ] **Video Recorded**: Recorded UI tests using the `ios-simulator-test-recording` skill.
- [ ] **Style Applied**: Ran `./scripts/style.sh` on changed files.

---

## 📝 Final Walkthrough Structure

The task is not done until a `walkthrough.md` artifact is created containing:
1.  **Summary of Changes**: High-level overview.
2.  **Public API Diff**: As requested in Step 4.
3.  **Video Link**: Path to the recorded UI test.
4.  **Network Traces**: Snippets of real requests and responses used.
5.  **API Behaviours**: A reference to the updates in the `FirebaseAI/behaviours/` directory.
6.  **Copy-Pastable Snippet**: A complete command line snippet showing how to run the test app and tests, including
    copying the `GoogleService-Info.plist` using the `firebase-test-configs` skill.

---

## 🧠 Post Change: Continuous Improvement
After completing the task and creating the walkthrough, you must perform a self-reflection:
1.  **Challenges Discovered**: What was harder than expected? Did you encounter gaps in documentation or tooling?
2.  **Knowledge Updates**: If you discovered a new pattern, fixed a tricky bug, or found a better way to do something,
    provide updates to this file (`agents.md`) or create/update a Knowledge Item to help future agents avoid the same
    issues.
