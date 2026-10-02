/*
 * Copyright 2026 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import FirebaseCore
@testable import FirebaseFirestore
import Foundation
import Testing

private struct Fruit: Codable, Equatable {
  var name: String
}

private func makeTestOptions() -> FirebaseOptions {
  let options = FirebaseOptions(googleAppID: "1:1234567890:ios:abcdef", gcmSenderID: "1234567890")
  options.projectID = "Firestore-Testing-Project"
  return options
}

/// `FirestoreQueryObservable` uses the default app's Firestore instance.
@MainActor
private let defaultApp: FirebaseApp = {
  if let app = FirebaseApp.app() { return app }
  FirebaseApp.configure(options: makeTestOptions())
  return FirebaseApp.app()!
}()

/// A separate, offline Firestore instance with a memory cache that is only used to create real
/// `QuerySnapshot`s for the tests.
@MainActor
private let snapshotSource: Firestore = {
  let name = "FirestoreQueryObservableTests"
  if FirebaseApp.app(name: name) == nil {
    FirebaseApp.configure(name: name, options: makeTestOptions())
  }
  let db = Firestore.firestore(app: FirebaseApp.app(name: name)!)
  let settings = db.settings
  settings.cacheSettings = MemoryCacheSettings()
  db.settings = settings
  return db
}()

/// Returns a snapshot with one document that decodes as a `Fruit` and one that doesn't.
@MainActor
private func snapshotWithUndecodableDocument() async throws -> QuerySnapshot {
  try await snapshotSource.disableNetwork()
  let collection = snapshotSource.collection("fruits-\(UUID().uuidString)")
  // The writes complete only when they reach the backend, so don't wait for them. Their local
  // results are visible to the cache query below.
  collection.document("apple").setData(["name": "Apple"], completion: nil)
  collection.document("broken").setData(["name": 42], completion: nil)
  return try await collection.getDocuments(source: .cache)
}

// MARK: - Listener capture

private typealias SnapshotListener = (QuerySnapshot?, Error?) -> Void

/// Holds the listener most recently registered through `Query.addSnapshotListener(_:)` while
/// the implementation is swapped by `swapAddSnapshotListener()`.
private final class RegisteredListener: @unchecked Sendable {
  private let lock = NSLock()
  private var listener: SnapshotListener?

  func store(_ listener: @escaping SnapshotListener) {
    lock.lock()
    defer { lock.unlock() }
    self.listener = listener
  }

  func take() -> SnapshotListener? {
    lock.lock()
    defer { lock.unlock() }
    let listener = self.listener
    self.listener = nil
    return listener
  }
}

private let registeredListener = RegisteredListener()

private final class FakeListenerRegistration: NSObject, ListenerRegistration {
  func remove() {}
}

private extension Query {
  @objc func queryObservableTests_addSnapshotListener(_ listener: @escaping SnapshotListener)
    -> ListenerRegistration {
    registeredListener.store(listener)
    return FakeListenerRegistration()
  }
}

/// Swaps `Query.addSnapshotListener(_:)` with a fake that records the listener instead of
/// listening. Calling it again restores the original implementation.
private func swapAddSnapshotListener() {
  let originalSelector = #selector(Query.addSnapshotListener(_:))
  let fakeSelector = #selector(Query.queryObservableTests_addSnapshotListener(_:))
  guard let originalMethod = class_getInstanceMethod(Query.self, originalSelector),
        let fakeMethod = class_getInstanceMethod(Query.self, fakeSelector) else {
    Issue.record("Failed to get methods for swizzling")
    return
  }
  method_exchangeImplementations(originalMethod, fakeMethod)
}

/// Delivers `snapshot` to the listener that the observable registered last.
private func deliver(_ snapshot: QuerySnapshot) throws {
  let listener = try #require(registeredListener.take())
  listener(snapshot, nil)
}

// MARK: - Tests

// Each test swaps the listener implementation only around synchronous code, so that no other
// test can observe the swapped implementation.
@Suite("FirestoreQueryObservable Tests")
struct FirestoreQueryObservableTests {
  @MainActor
  @Test("Array results are cleared after a decoding failure with the .raise strategy")
  func arrayResultsAreClearedOnDecodingFailureWithRaiseStrategy() async throws {
    let snapshot = try await snapshotWithUndecodableDocument()
    _ = defaultApp

    swapAddSnapshotListener()
    defer { swapAddSnapshotListener() }
    let observable = FirestoreQueryObservable<[Fruit]>(
      configuration: .init(path: "fruits", predicates: [], decodingFailureStrategy: .raise)
    )
    try deliver(snapshot)

    #expect(observable.items.isEmpty)
    #expect(observable.configuration.error != nil)
  }

  @MainActor
  @Test("Array results keep decoded documents after a decoding failure with .ignore")
  func arrayResultsKeepDecodedDocumentsWithIgnoreStrategy() async throws {
    let snapshot = try await snapshotWithUndecodableDocument()
    _ = defaultApp

    swapAddSnapshotListener()
    defer { swapAddSnapshotListener() }
    let observable = FirestoreQueryObservable<[Fruit]>(
      configuration: .init(path: "fruits", predicates: [], decodingFailureStrategy: .ignore)
    )
    try deliver(snapshot)

    #expect(observable.items == [Fruit(name: "Apple")])
    #expect(observable.configuration.error != nil)
  }

  @MainActor
  @Test("Array results use the updated decoding failure strategy")
  func arrayResultsUseUpdatedDecodingFailureStrategy() async throws {
    let snapshot = try await snapshotWithUndecodableDocument()
    _ = defaultApp

    swapAddSnapshotListener()
    defer { swapAddSnapshotListener() }
    let observable = FirestoreQueryObservable<[Fruit]>(
      configuration: .init(path: "fruits", predicates: [], decodingFailureStrategy: .ignore)
    )
    // Re-registers the listener.
    observable.configuration.decodingFailureStrategy = .raise
    try deliver(snapshot)

    #expect(observable.items.isEmpty)
    #expect(observable.configuration.error != nil)
  }

  @MainActor
  @Test("Result results use the updated decoding failure strategy")
  func resultResultsUseUpdatedDecodingFailureStrategy() async throws {
    let snapshot = try await snapshotWithUndecodableDocument()
    _ = defaultApp

    swapAddSnapshotListener()
    defer { swapAddSnapshotListener() }
    let observable = FirestoreQueryObservable<Result<[Fruit], Error>>(
      configuration: .init(path: "fruits", predicates: [], decodingFailureStrategy: .raise)
    )
    // Re-registers the listener.
    observable.configuration.decodingFailureStrategy = .ignore
    try deliver(snapshot)

    let fruits = try observable.items.get()
    #expect(fruits == [Fruit(name: "Apple")])
    #expect(observable.configuration.error != nil)
  }
}
