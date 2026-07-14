# Review Guidelines

This document outlines subjective, team-specific code review standards. Any AI
agent (like the TDD Reviewer or PR Reviewer) operating in this repository must
rigorously critique code against these guidelines.

## 1. Swift-First & Concurrency
* **No New Objective-C**: Reject any PR that introduces new Objective-C code
  unless there is a strong, explicitly documented justification (e.g.,
  C-interop).
* **Async/Await**: All new asynchronous APIs must use Swift Concurrency
  (`async/await`). Reject new callback-based APIs unless they are specifically
  for event streams.
* **Task Cancellation**: Rigorously verify that unstructured `Task`s or
  `AsyncStream`s properly handle cancellation in their `onTermination` closures
  to prevent resource leaks.
* **`[weak self]`**: Challenge the blind use of `[weak self]`. Only use it when
  a genuine retain cycle exists.

## 2. API Design & Safety
* **Core API Guidelines**: You MUST read and enforce the rules defined in the
  Firebase API guidelines document. First check for
  `docs/firebase-api-guidelines.md` at the root of the current repository. If
  it does not exist, look for it in
  `~/Developer/firebase-ios-sdk/docs/firebase-api-guidelines.md` or read the
  user's cached SDK path from `~/.gemini/config/.firebase_sdk_path`.
* **Strict Typing**: Reject the use of `Any`, `AnyObject`, or `NS`-prefixed
  types (like `NSString`, `NSDictionary`) in public Swift APIs. Demand native
  Swift types.
* **Error Handling**: Ensure all new failure states are properly modeled. Any
  new error must be added to the module's dedicated Error enum.
* **Extensibility**: For values that might expand in the future, prefer
  `struct`s with static factory methods over `enum`s to prevent breaking
  changes when adding cases.

## 3. General Best Practices
* **Testing**: Reject PRs that fix bugs without adding a corresponding
  regression test.
* **Documentation**: Ensure all new public APIs are documented using
  Swift-flavored Markdown.

---
*Note to core team: Treat this as a living document. Add new subjective review
standards here as your team discovers new friction points.*
