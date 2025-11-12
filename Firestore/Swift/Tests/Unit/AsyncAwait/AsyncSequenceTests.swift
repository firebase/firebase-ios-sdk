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

private final class AssociationKey: Sendable {}

/// A wrapper to safely pass a non-Sendable closure to a Sendable context.
///
/// This is safe in this specific test because the listener closure originates from
/// an `AsyncStream` continuation, which is guaranteed to be thread-safe.
private final class SendableListenerWrapper: @unchecked Sendable {
  let listener: (QuerySnapshot?, Error?) -> Void

  init(_ listener: @escaping (QuerySnapshot?, Error?) -> Void) {
    self.listener = listener
  }
}

@Suite("Query AsyncSequence Tests")
struct AsyncSequenceTests {
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

  // Swizzling is managed by this helper struct using a simple RAII pattern.
  // The swizzling is active for the lifetime of the struct instance.
  private struct Swizzler: ~Copyable {
    init() {
      Self.swizzle(
        Query.self,
        originalSelector: #selector(Query.addSnapshotListener(includeMetadataChanges:listener:)),
        swizzledSelector: #selector(Query.swizzled_addSnapshotListener(includeMetadataChanges:listener:))
      )
    }

    deinit {
      Self.swizzle(
        Query.self,
        originalSelector: #selector(Query.swizzled_addSnapshotListener(includeMetadataChanges:listener:)),
        swizzledSelector: #selector(Query.addSnapshotListener(includeMetadataChanges:listener:))
      )
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

  @available(iOS 18.0, *)
  @MainActor
  @Test("Stream handles cancellation correctly")
  func test_snapshotStream_handlesCancellationCorrectly() async throws {
    // Ensure Firebase is configured before swizzling, as interacting with the
    // Query class can trigger SDK initialization that requires a configured app.
    let app = Self.firebaseApp
    let swizzler = Swizzler()
    defer { withExtendedLifetime(swizzler) {} }

    let actor = TestStateActor()
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
    // Ensure Firebase is configured before swizzling, as interacting with the
    // Query class can trigger SDK initialization that requires a configured app.
    let app = Self.firebaseApp
    let swizzler = Swizzler()
    defer { withExtendedLifetime(swizzler) {} }

    let actor = TestStateActor()
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
    // Ensure Firebase is configured before swizzling, as interacting with the
    // Query class can trigger SDK initialization that requires a configured app.
    let app = Self.firebaseApp
    let swizzler = Swizzler()
    defer { withExtendedLifetime(swizzler) {} }

    let actor = TestStateActor()
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

private enum TestError: Error, Equatable {
  case mockError
}

// We can finally use a real actor, which is much safer and cleaner.
private actor TestStateActor {
  private var capturedListenerWrapper: SendableListenerWrapper?
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

  func listenerDidSetUp(wrapper: SendableListenerWrapper) {
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

  func invokeListener(withSnapshot snapshot: QuerySnapshot?, error: Error?) {
    capturedListenerWrapper?.listener(snapshot, error)
  }
}

private final class MockListenerRegistration: NSObject, ListenerRegistration {
  private var actor: TestStateActor

  init(actor: TestStateActor) {
    self.actor = actor
  }

  func remove() {
    let actor = self.actor
    Task {
      await actor.listenerDidRemove()
    }
  }
}

extension Query {
  @objc func swizzled_addSnapshotListener(
    includeMetadataChanges: Bool,
    listener: @escaping (QuerySnapshot?, Error?) -> Void
  ) -> ListenerRegistration {
    let key = Unmanaged.passUnretained(AsyncSequenceTests.associationKey).toOpaque()
    let actor = objc_getAssociatedObject(self, key) as! TestStateActor
    let registration = MockListenerRegistration(actor: actor)
    let wrapper = SendableListenerWrapper(listener)
    Task {
        await actor.listenerDidSetUp(wrapper: wrapper)
    }
    return registration
  }
}

extension String: Error {}
