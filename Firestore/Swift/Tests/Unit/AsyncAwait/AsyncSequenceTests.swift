// SPDX-License-Identifier: Apache-2.0
//
// Copyright 2024 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Testing
import FirebaseCore
@testable import FirebaseFirestore

// MARK: - Shared Test Helpers

private final class AssociationKey: Sendable {}

private enum TestError: Error, Equatable {
  case mockError
}

/// A protocol to allow the `MockListenerRegistration` to call back to the actor
/// without needing to know its generic type.
private protocol ListenerRemovable: Sendable {
  func listenerDidRemove() async
}

/// A wrapper to safely pass a non-Sendable closure to a Sendable context.
///
/// This is safe in this specific test because the listener closure originates from
/// an `AsyncStream` continuation, which is guaranteed to be thread-safe.
private final class SendableListenerWrapper<SnapshotType>: @unchecked Sendable {
  let listener: (SnapshotType?, Error?) -> Void

  init(_ listener: @escaping (SnapshotType?, Error?) -> Void) {
    self.listener = listener
  }
}

/// An actor to manage test state, ensuring thread-safe access to continuations
/// and the captured listener closure.
private actor TestStateActor<SnapshotType>: ListenerRemovable {
  private var capturedListenerWrapper: SendableListenerWrapper<SnapshotType>?
  private var listenerSetupContinuation: CheckedContinuation<Void, Never>?
  private var listenerRemovedContinuation: CheckedContinuation<Void, Never>?

  private var hasSetUpListener = false
  private var hasRemovedListener = false

  func waitForListenerSetup() async {
    if hasSetUpListener { return }
    await withCheckedContinuation { continuation in
      self.listenerSetupContinuation = continuation
    }
  }

  func waitForListenerRemoval() async {
    if hasRemovedListener { return }
    await withCheckedContinuation { continuation in
      self.listenerRemovedContinuation = continuation
    }
  }

  func listenerDidSetUp(wrapper: SendableListenerWrapper<SnapshotType>) {
    capturedListenerWrapper = wrapper
    hasSetUpListener = true
    listenerSetupContinuation?.resume()
    listenerSetupContinuation = nil
  }

  func listenerDidRemove() {
    hasRemovedListener = true
    listenerRemovedContinuation?.resume()
    listenerRemovedContinuation = nil
  }

  func invokeListener(withSnapshot snapshot: SnapshotType?, error: Error?) {
    capturedListenerWrapper?.listener(snapshot, error)
  }
}

private final class MockListenerRegistration: NSObject, ListenerRegistration {
  private var actor: any ListenerRemovable

  init(actor: any ListenerRemovable) {
    self.actor = actor
  }

  func remove() {
    let actor = self.actor
    Task {
      await actor.listenerDidRemove()
    }
  }
}

// Swizzling is managed by this helper struct using a simple RAII pattern.
// The swizzling is active for the lifetime of the struct instance.
private struct Swizzler: ~Copyable {
  private let cls: AnyClass
  private let original: Selector
  private let swizzled: Selector

  init(_ cls: AnyClass, original: Selector, swizzled: Selector) {
    self.cls = cls
    self.original = original
    self.swizzled = swizzled
    Self.swizzle(cls, originalSelector: original, swizzledSelector: swizzled)
  }

  deinit {
    Self.swizzle(cls, originalSelector: swizzled, swizzledSelector: original)
  }

  private static func swizzle(_ cls: AnyClass, originalSelector: Selector, swizzledSelector: Selector) {
    guard let originalMethod = class_getInstanceMethod(cls, originalSelector),
          let swizzledMethod = class_getInstanceMethod(cls, swizzledSelector) else {
      #expect(false, "Failed to get methods for swizzling")
      return
    }
    method_exchangeImplementations(originalMethod, swizzledMethod)
  }
}

// MARK: - Query Tests

@Suite("Query AsyncSequence Tests")
struct QueryAsyncSequenceTests {
  fileprivate static let associationKey = AssociationKey()

  // This static property handles the one-time setup for FirebaseApp.
  @MainActor
  private static let firebaseApp: FirebaseApp = {
    let options = FirebaseOptions(googleAppID: "1:1234567890:ios:abcdef",
                                  gcmSenderID: "1234s567890")
    options.projectID = "Firestore-Testing-Project"
    FirebaseApp.configure(options: options)
    return FirebaseApp.app()!
  }()

  @available(iOS 18.0, *)
  @MainActor
  @Test("Stream handles cancellation correctly")
  func test_snapshotStream_handlesCancellationCorrectly() async throws {
    let app = Self.firebaseApp
    let swizzler = Swizzler(
      Query.self,
      original: #selector(Query.addSnapshotListener(includeMetadataChanges:listener:)),
      swizzled: #selector(Query.swizzled_addSnapshotListener(includeMetadataChanges:listener:))
    )
    defer { withExtendedLifetime(swizzler) {} }

    let actor = TestStateActor<QuerySnapshot>()
    let query = Firestore.firestore(app: app)
      .collection("test-\(UUID().uuidString)")
    let key = Unmanaged.passUnretained(Self.associationKey).toOpaque()
    objc_setAssociatedObject(query, key, actor, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

    let task = Task {
      for try await _ in query.snapshots {
        // Do nothing
      }
    }

    await actor.waitForListenerSetup()
    task.cancel()
    await actor.waitForListenerRemoval()
  }

  @available(iOS 18.0, *)
  @MainActor
  @Test("Stream propagates errors")
  func test_snapshotStream_propagatesErrors() async throws {
    let app = Self.firebaseApp
    let swizzler = Swizzler(
      Query.self,
      original: #selector(Query.addSnapshotListener(includeMetadataChanges:listener:)),
      swizzled: #selector(Query.swizzled_addSnapshotListener(includeMetadataChanges:listener:))
    )
    defer { withExtendedLifetime(swizzler) {} }

    let actor = TestStateActor<QuerySnapshot>()
    let query = Firestore.firestore(app: app)
      .collection("test-\(UUID().uuidString)")
    let key = Unmanaged.passUnretained(Self.associationKey).toOpaque()
    objc_setAssociatedObject(query, key, actor, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

    let task = Task {
      do {
        for try await _ in query.snapshots {}
        throw "Stream did not throw"
      } catch {
        return error
      }
    }

    await actor.waitForListenerSetup()
    await actor.invokeListener(withSnapshot: nil, error: TestError.mockError)

    let caughtError = await task.value
    #expect(caughtError as? TestError == .mockError)
    task.cancel()
  }

  @available(iOS 18.0, *)
  @MainActor
  @Test("Stream handles (nil, nil) events gracefully")
  func test_snapshotStream_handlesNilSnapshotAndNilErrorGracefully() async throws {
    let app = Self.firebaseApp
    let swizzler = Swizzler(
      Query.self,
      original: #selector(Query.addSnapshotListener(includeMetadataChanges:listener:)),
      swizzled: #selector(Query.swizzled_addSnapshotListener(includeMetadataChanges:listener:))
    )
    defer { withExtendedLifetime(swizzler) {} }

    let actor = TestStateActor<QuerySnapshot>()
    let query = Firestore.firestore(app: app)
      .collection("test-\(UUID().uuidString)")
    let key = Unmanaged.passUnretained(Self.associationKey).toOpaque()
    objc_setAssociatedObject(query, key, actor, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

    let task = Task {
      for try await _ in query.snapshots {
        #expect(false, "The stream should not have produced any values.")
      }
    }

    await actor.waitForListenerSetup()
    await actor.invokeListener(withSnapshot: nil, error: nil)
    task.cancel()
    await actor.waitForListenerRemoval()

    // Awaiting the task will rethrow a CancellationError, which is expected
    // and handled by the `throws` on the test function.
    try await task.value
  }
}

// MARK: - DocumentReference Tests

@Suite("DocumentReference AsyncSequence Tests")
struct DocumentReferenceAsyncSequenceTests {
  fileprivate static let associationKey = AssociationKey()

  @MainActor
  private static let firebaseApp: FirebaseApp = {
    // This will either configure a new app or return the existing one
    // from the Query tests, which is safe.
    if let app = FirebaseApp.app() { return app }
    let options = FirebaseOptions(googleAppID: "1:1234567890:ios:abcdef",
                                  gcmSenderID: "1234s567890")
    options.projectID = "Firestore-Testing-Project"
    FirebaseApp.configure(options: options)
    return FirebaseApp.app()!
  }()

  @available(iOS 18.0, *)
  @MainActor
  @Test("Stream handles cancellation correctly")
  func test_snapshotStream_handlesCancellationCorrectly() async throws {
    let app = Self.firebaseApp
    let swizzler = Swizzler(
      DocumentReference.self,
      original: #selector(DocumentReference.addSnapshotListener(includeMetadataChanges:listener:)),
      swizzled: #selector(DocumentReference.swizzled_addSnapshotListener(includeMetadataChanges:listener:))
    )
    defer { withExtendedLifetime(swizzler) {} }

    let actor = TestStateActor<DocumentSnapshot>()
    let docRef = Firestore.firestore(app: app)
      .collection("test-\(UUID().uuidString)").document()
    let key = Unmanaged.passUnretained(Self.associationKey).toOpaque()
    objc_setAssociatedObject(docRef, key, actor, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

    let task = Task {
      for try await _ in docRef.snapshots {
        // Do nothing
      }
    }

    await actor.waitForListenerSetup()
    task.cancel()
    await actor.waitForListenerRemoval()
  }

  @available(iOS 18.0, *)
  @MainActor
  @Test("Stream propagates errors")
  func test_snapshotStream_propagatesErrors() async throws {
    let app = Self.firebaseApp
    let swizzler = Swizzler(
      DocumentReference.self,
      original: #selector(DocumentReference.addSnapshotListener(includeMetadataChanges:listener:)),
      swizzled: #selector(DocumentReference.swizzled_addSnapshotListener(includeMetadataChanges:listener:))
    )
    defer { withExtendedLifetime(swizzler) {} }

    let actor = TestStateActor<DocumentSnapshot>()
    let docRef = Firestore.firestore(app: app)
      .collection("test-\(UUID().uuidString)").document()
    let key = Unmanaged.passUnretained(Self.associationKey).toOpaque()
    objc_setAssociatedObject(docRef, key, actor, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

    let task = Task {
      do {
        for try await _ in docRef.snapshots {}
        throw "Stream did not throw"
      } catch {
        return error
      }
    }

    await actor.waitForListenerSetup()
    await actor.invokeListener(withSnapshot: nil, error: TestError.mockError)

    let caughtError = await task.value
    #expect(caughtError as? TestError == .mockError)
    task.cancel()
  }

  @available(iOS 18.0, *)
  @MainActor
  @Test("Stream handles (nil, nil) events gracefully")
  func test_snapshotStream_handlesNilSnapshotAndNilErrorGracefully() async throws {
    let app = Self.firebaseApp
    let swizzler = Swizzler(
      DocumentReference.self,
      original: #selector(DocumentReference.addSnapshotListener(includeMetadataChanges:listener:)),
      swizzled: #selector(DocumentReference.swizzled_addSnapshotListener(includeMetadataChanges:listener:))
    )
    defer { withExtendedLifetime(swizzler) {} }

    let actor = TestStateActor<DocumentSnapshot>()
    let docRef = Firestore.firestore(app: app)
      .collection("test-\(UUID().uuidString)").document()
    let key = Unmanaged.passUnretained(Self.associationKey).toOpaque()
    objc_setAssociatedObject(docRef, key, actor, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

    let task = Task {
      for try await _ in docRef.snapshots {
        #expect(false, "The stream should not have produced any values.")
      }
    }

    await actor.waitForListenerSetup()
    await actor.invokeListener(withSnapshot: nil, error: nil)
    task.cancel()
    await actor.waitForListenerRemoval()

    // Awaiting the task will rethrow a CancellationError, which is expected
    // and handled by the `throws` on the test function.
    try await task.value
  }
}

// MARK: - Method Swizzling

extension Query {
  @objc func swizzled_addSnapshotListener(
    includeMetadataChanges: Bool,
    listener: @escaping (QuerySnapshot?, Error?) -> Void
  ) -> ListenerRegistration {
    let key = Unmanaged.passUnretained(QueryAsyncSequenceTests.associationKey).toOpaque()
    let actor = objc_getAssociatedObject(self, key) as! TestStateActor<QuerySnapshot>
    let registration = MockListenerRegistration(actor: actor)
    let wrapper = SendableListenerWrapper(listener)
    Task {
      await actor.listenerDidSetUp(wrapper: wrapper)
    }
    return registration
  }
}

extension DocumentReference {
  @objc func swizzled_addSnapshotListener(
    includeMetadataChanges: Bool,
    listener: @escaping (DocumentSnapshot?, Error?) -> Void
  ) -> ListenerRegistration {
    let key = Unmanaged.passUnretained(DocumentReferenceAsyncSequenceTests.associationKey).toOpaque()
    let actor = objc_getAssociatedObject(self, key) as! TestStateActor<DocumentSnapshot>
    let registration = MockListenerRegistration(actor: actor)
    let wrapper = SendableListenerWrapper(listener)
    Task {
      await actor.listenerDidSetUp(wrapper: wrapper)
    }
    return registration
  }
}

extension String: Error {}
