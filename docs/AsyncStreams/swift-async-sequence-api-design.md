# API Design for Firebase `AsyncSequence` Event Streams

* **Authors**
  * Peter Friese
* **Contributors**
  * Nick Cooke
  * Paul Beusterien
* **Status**: `In Review`
* **Last Updated**: 2025-09-25

## 1. Abstract

This proposal outlines the integration of Swift's `AsyncStream` and `AsyncSequence` APIs into the Firebase Apple SDK. The goal is to provide a modern, developer-friendly way to consume real-time data streams from Firebase APIs, aligning the SDK with Swift's structured concurrency model and improving the overall developer experience.

## 2. Background

Many Firebase APIs produce a sequence of asynchronous events, such as authentication state changes, document and collection updates, and remote configuration updates. Currently, the SDK exposes these through completion-handler-based APIs (listeners).

```swift
// Current listener-based approach
db.collection("cities").document("SF")
  .addSnapshotListener { documentSnapshot, error in
    guard let document = documentSnapshot else { /* ... */ }
    guard let data = document.data() else { /* ... */ }
    print("Current data: \(data)")
  }
```

This approach breaks the otherwise linear control flow, requires manual management of listener lifecycles, and complicates error handling. Swift's `AsyncSequence` provides a modern, type-safe alternative that integrates seamlessly with structured concurrency, offering automatic resource management, simplified error handling, and a more intuitive, linear control flow.

## 3. Motivation

Adopting `AsyncSequence` will:

*   **Modernize the SDK:** Align with Swift's modern concurrency approach, making Firebase feel more native to Swift developers.
*   **Simplify Development:** Eliminate the need for manual listener management and reduce boilerplate code, especially when integrating with SwiftUI.
*   **Improve Code Quality:** Provide official, high-quality implementations for streaming APIs, reducing ecosystem fragmentation caused by unofficial solutions.
*   **Enhance Readability:** Leverage structured error handling (`throws`) and a linear `for try await` syntax to make asynchronous code easier to read and maintain.
*   **Enable Composition:** Allow developers to use a rich set of sequence operators (like `map`, `filter`, `prefix`) to transform and combine streams declaratively.

## 4. Goals

*   To design and implement an idiomatic, `AsyncSequence`-based API surface for all relevant event-streaming Firebase APIs.
*   To provide a clear and consistent naming convention that aligns with Apple's own Swift APIs.
*   To ensure the new APIs automatically manage the lifecycle of underlying listeners, removing this burden from the developer.
*   To improve the testability of asynchronous Firebase interactions.

## 5. Non-Goals

*   To deprecate or remove the existing listener-based APIs in the immediate future. The new APIs will be additive.
*   To introduce `AsyncSequence` wrappers for one-shot asynchronous calls (which are better served by `async/await` functions). This proposal is focused exclusively on event streams.
*   To provide a custom `AsyncSequence` implementation. We will use Swift's standard `Async(Throwing)Stream` types.

## 6. API Naming Convention

The guiding principle is to establish a clear, concise, and idiomatic naming convention that aligns with modern Swift practices and mirrors Apple's own frameworks.

### Recommended Approach: Name the sequence based on its conceptual model.

1.  **For sequences of discrete items, use a plural noun.**
    *   This applies when the stream represents a series of distinct objects, like data snapshots.
    *   **Guidance:** Use a computed property for parameter-less access and a method for cases that require parameters.
    *   **Examples:** `url.lines`, `db.collection("users").snapshots`.

2.  **For sequences observing a single entity, describe the event with a suffix.**
    *   This applies when the stream represents the changing value of a single property or entity over time.
    *   **Guidance:** Use the entity's name combined with a suffix like `Changes`, `Updates`, or `Events`.
    *   **Example:** `auth.authStateChanges`.

This approach was chosen over verb-based (`.streamSnapshots()`) or suffix-based (`.snapshotStream`) alternatives because it aligns most closely with Apple's API design guidelines, leading to a more idiomatic and less verbose call site.

## 7. Proposed API Design

### 7.1. Cloud Firestore

Provides an async alternative to `addSnapshotListener`.

#### API Design

```swift
// Collection snapshots
extension CollectionReference {
  var snapshots: AsyncThrowingStream<QuerySnapshot, Error> { get }
  func snapshots(includeMetadataChanges: Bool = false) -> AsyncThrowingStream<QuerySnapshot, Error>
}

// Query snapshots
extension Query {
  var snapshots: AsyncThrowingStream<QuerySnapshot, Error> { get }
  func snapshots(includeMetadataChanges: Bool = false) -> AsyncThrowingStream<QuerySnapshot, Error>
}

// Document snapshots
extension DocumentReference {
  var snapshots: AsyncThrowingStream<DocumentSnapshot, Error> { get }
  func snapshots(includeMetadataChanges: Bool = false) -> AsyncThrowingStream<DocumentSnapshot, Error>
}
```

#### Usage

```swift
// Streaming updates on a collection
func observeUsers() async throws {
  for try await snapshot in db.collection("users").snapshots {
    // ...
  }
}
```

### 7.2. Realtime Database

Provides an async alternative to the `observe(_:with:)` method.

#### API Design

```swift
/// An enumeration of granular child-level events.
public enum DatabaseEvent {
    case childAdded(DataSnapshot, previousSiblingKey: String?)
    case childChanged(DataSnapshot, previousSiblingKey: String?)
    case childRemoved(DataSnapshot)
    case childMoved(DataSnapshot, previousSiblingKey: String?)
}

extension DatabaseQuery {
  /// An asynchronous stream of the entire contents at a location.
  /// This stream emits a new `DataSnapshot` every time the data changes.
  var value: AsyncThrowingStream<DataSnapshot, Error> { get }

  /// An asynchronous stream of child-level events at a location.
  func events() -> AsyncThrowingStream<DatabaseEvent, Error>
}
```

#### Usage

```swift
// Streaming a single value
let scoreRef = Database.database().reference(withPath: "game/score")
for try await snapshot in scoreRef.value {
  // ...
}

// Streaming child events
let messagesRef = Database.database().reference(withPath: "chats/123/messages")
for try await event in messagesRef.events() {
  switch event {
    case .childAdded(let snapshot, _):
      // ...
    // ...
  }
}
```

### 7.3. Authentication

Provides an async alternative to `addStateDidChangeListener`.

#### API Design

```swift
extension Auth {
  /// An asynchronous stream of authentication state changes.
  var authStateChanges: AsyncStream<User?> { get }
}
```

#### Usage

```swift
// Monitoring authentication state
for await user in Auth.auth().authStateChanges {
  if let user = user {
    // User is signed in
  } else {
    // User is signed out
  }
}
```

### 7.4. Cloud Storage

Provides an async alternative to `observe(.progress, ...)`.

#### API Design

```swift
extension StorageTask {
  /// An asynchronous stream of progress updates for an ongoing task.
  var progressUpdates: AsyncThrowingStream<StorageTaskSnapshot, Error> { get }
}
```

#### Usage

```swift
// Monitoring an upload task
let uploadTask = ref.putData(data, metadata: nil)
do {
  for try await progress in uploadTask.progress {
    // Update progress bar
  }
  print("Upload complete")
} catch {
  // Handle error
}
```

### 7.5. Remote Config

Provides an async alternative to `addOnConfigUpdateListener`.

#### API Design

```swift
extension RemoteConfig {
  /// An asynchronous stream of configuration updates.
  var updates: AsyncThrowingStream<RemoteConfigUpdate, Error> { get }
}
```

#### Usage

```swift
// Listening for real-time config updates
for try await update in RemoteConfig.remoteConfig().updates {
  // Activate new config
}
```

### 7.6. Cloud Messaging (FCM)

Provides an async alternative to the delegate-based approach for token updates and foreground messages.

#### API Design

```swift
extension Messaging {
  /// An asynchronous stream of FCM registration token updates.
  var tokenUpdates: AsyncStream<String> { get }

  /// An asynchronous stream of remote messages received while the app is in the foreground.
  var foregroundMessages: AsyncStream<MessagingRemoteMessage> { get }
}
```

#### Usage

```swift
// Monitoring FCM token updates
for await token in Messaging.messaging().tokenUpdates {
  // Send token to server
}
```

## 8. Testing Plan

The quality and reliability of this new API surface will be ensured through a multi-layered testing strategy, covering unit, integration, and cancellation scenarios.

### 8.1. Unit Tests

The primary goal of unit tests is to verify the correctness of the `AsyncStream` wrapping logic in isolation from the network and backend services.

*   **Mocking:** Each product's stream implementation will be tested against a mocked version of its underlying service (e.g., a mock `Firestore` client).
*   **Behavior Verification:**
    *   Tests will confirm that initiating a stream correctly registers a listener with the underlying service.
    *   We will use the mock listeners to simulate events (e.g., new snapshots, auth state changes) and assert that the `AsyncStream` yields the corresponding values correctly.
    *   Error conditions will be simulated to ensure that the stream correctly throws errors.
*   **Teardown Logic:** We will verify that the underlying listener is removed when the stream is either cancelled or finishes naturally.

### 8.2. Integration Tests

Integration tests will validate the end-to-end functionality of the async sequences against a live backend environment using the **Firebase Emulator Suite**.

*   **Environment:** A new integration test suite will be created that configures the Firebase SDK to connect to the local emulators (Firestore, Database, Auth, etc.).
*   **Validation:** These tests will perform real operations (e.g., writing a document and then listening to its `snapshots` stream) to verify that real-time updates are correctly received and propagated through the `AsyncSequence` API.
*   **Cross-Product Scenarios:** We will test scenarios that involve multiple Firebase products where applicable.

### 8.3. Cancellation Behavior Tests

A specific set of tests will be dedicated to ensuring that resource cleanup (i.e., listener removal) happens correctly and promptly when the consuming task is cancelled.

*   **Test Scenario:**
    1.  A stream will be consumed within a Swift `Task`.
    2.  The `Task` will be cancelled immediately after the stream is initiated.
    3.  Using a mock or a spy object, we will assert that the `remove()` method on the underlying listener registration is called.
*   **Importance:** This is critical for preventing resource leaks and ensuring the new API behaves predictably within the Swift structured concurrency model, especially in SwiftUI contexts where tasks are automatically managed.

## 9. Implementation Plan

The implementation will be phased, with each product's API being added in a separate Pull Request to facilitate focused reviews.

*   **Firestore:** [PR #14924: Support AsyncStream in realtime query](https://github.com/firebase/firebase-ios-sdk/pull/14924)
*   **Authentication:** [Link to PR when available]
*   **Realtime Database:** [Link to PR when available]
*   ...and so on.

## 10. Open Questions & Future Work

*   Should we provide convenience wrappers for common `AsyncSequence` operators? (e.g., a method to directly stream decoded objects instead of snapshots). For now, this is considered a **Non-Goal** but could be revisited.
