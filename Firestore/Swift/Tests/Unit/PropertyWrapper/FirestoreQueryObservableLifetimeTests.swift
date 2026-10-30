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

private struct Fruit: Decodable {
  var name: String
}

/// `FirestoreQueryObservable` uses the default app's Firestore instance.
@MainActor
private let defaultApp: FirebaseApp = {
  if let app = FirebaseApp.app() { return app }
  let options = FirebaseOptions(googleAppID: "1:1234567890:ios:abcdef", gcmSenderID: "1234567890")
  options.projectID = "Firestore-Testing-Project"
  FirebaseApp.configure(options: options)
  return FirebaseApp.app()!
}()

// MARK: - Fake snapshot listener

private typealias SnapshotListener = (QuerySnapshot?, Error?) -> Void

/// A registration that, like a real one, keeps its listener until it's removed, but doesn't
/// listen to anything.
private final class RecordingListenerRegistration: NSObject, ListenerRegistration {
  private var listener: SnapshotListener?
  private(set) var removeCount = 0

  init(listener: @escaping SnapshotListener) {
    self.listener = listener
  }

  func remove() {
    removeCount += 1
    listener = nil
  }
}

/// Collects the registrations that the fake `addSnapshotListener(_:)` hands out.
private final class HandedOutRegistrations: @unchecked Sendable {
  private let lock = NSLock()
  private var registrations: [RecordingListenerRegistration] = []

  func append(_ registration: RecordingListenerRegistration) {
    lock.lock()
    defer { lock.unlock() }
    registrations.append(registration)
  }

  func takeAll() -> [RecordingListenerRegistration] {
    lock.lock()
    defer { lock.unlock() }
    let registrations = self.registrations
    self.registrations = []
    return registrations
  }
}

private let handedOutRegistrations = HandedOutRegistrations()

private extension Query {
  @objc func lifetimeTests_addSnapshotListener(_ listener: @escaping SnapshotListener)
    -> ListenerRegistration {
    let registration = RecordingListenerRegistration(listener: listener)
    handedOutRegistrations.append(registration)
    return registration
  }
}

/// Exchanges the implementations of `Query.addSnapshotListener(_:)` and the fake above.
private func exchangeAddSnapshotListenerImplementations() {
  let originalSelector = #selector(Query.addSnapshotListener(_:))
  let fakeSelector = #selector(Query.lifetimeTests_addSnapshotListener(_:))
  guard let originalMethod = class_getInstanceMethod(Query.self, originalSelector),
        let fakeMethod = class_getInstanceMethod(Query.self, fakeSelector) else {
    Issue.record("Failed to get methods for swizzling")
    return
  }
  method_exchangeImplementations(originalMethod, fakeMethod)
}

/// Runs `body` while `Query.addSnapshotListener(_:)` hands out `RecordingListenerRegistration`s
/// instead of listening, and returns the registrations that it handed out.
///
/// `body` is synchronous and runs on the main actor, so tests that run on the main actor can't
/// observe the fake. Because the real `addSnapshotListener(_:)` never runs, these tests also don't
/// reach `addSnapshotListener(includeMetadataChanges:listener:)`, which other tests swizzle.
@MainActor
private func withFakeSnapshotListener(_ body: () -> Void) -> [RecordingListenerRegistration] {
  exchangeAddSnapshotListenerImplementations()
  defer { exchangeAddSnapshotListenerImplementations() }
  body()
  return handedOutRegistrations.takeAll()
}

// MARK: - Tests

@Suite("FirestoreQueryObservable Lifetime Tests", .serialized)
struct FirestoreQueryObservableLifetimeTests {
  @MainActor
  @Test("Observable with array results is deallocated and removes its listener")
  func arrayObservableIsDeallocatedAndRemovesItsListener() throws {
    _ = defaultApp
    var observable: FirestoreQueryObservable<[Fruit]>?
    let registrations = withFakeSnapshotListener {
      observable = FirestoreQueryObservable<[Fruit]>(
        configuration: .init(path: "fruits", predicates: [])
      )
    }
    try #require(registrations.count == 1)

    weak let weakObservable = observable
    observable = nil

    #expect(weakObservable == nil, "The observable outlived its last strong reference.")
    #expect(registrations[0].removeCount == 1)
  }

  @MainActor
  @Test("Observable with Result results is deallocated and removes its listener")
  func resultObservableIsDeallocatedAndRemovesItsListener() throws {
    _ = defaultApp
    var observable: FirestoreQueryObservable<Result<[Fruit], Error>>?
    let registrations = withFakeSnapshotListener {
      observable = FirestoreQueryObservable<Result<[Fruit], Error>>(
        configuration: .init(path: "fruits", predicates: [])
      )
    }
    try #require(registrations.count == 1)

    weak let weakObservable = observable
    observable = nil

    #expect(weakObservable == nil, "The observable outlived its last strong reference.")
    #expect(registrations[0].removeCount == 1)
  }

  @MainActor
  @Test("Observable replaces its listener when the configuration changes and removes the new one")
  func observableRemovesTheListenerThatReplacedTheInitialOne() throws {
    _ = defaultApp
    var observable: FirestoreQueryObservable<[Fruit]>?
    let initialRegistrations = withFakeSnapshotListener {
      observable = FirestoreQueryObservable<[Fruit]>(
        configuration: .init(path: "fruits", predicates: [])
      )
    }
    let replacementRegistrations = withFakeSnapshotListener {
      observable?.configuration.path = "vegetables"
    }
    try #require(initialRegistrations.count == 1)
    try #require(replacementRegistrations.count == 1)
    #expect(initialRegistrations[0].removeCount == 1)
    #expect(replacementRegistrations[0].removeCount == 0)

    weak let weakObservable = observable
    observable = nil

    #expect(weakObservable == nil, "The observable outlived its last strong reference.")
    #expect(replacementRegistrations[0].removeCount == 1)
  }
}
