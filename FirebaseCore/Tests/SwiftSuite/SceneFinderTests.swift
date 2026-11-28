// Copyright 2026 Google LLC
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

#if os(iOS) || os(tvOS) || os(visionOS)

  import FirebaseCore
  internal import FirebaseCoreExtension
  import FirebaseCoreTestHooks
  import Foundation
  import ObjectiveC
  import UIKit
  import XCTest

  /// Tests for `SceneFinder`, which picks the foreground scene that FirebaseCore's products present
  /// UI in. They don't use OCMock, so they run unchanged against the Objective-C and Swift
  /// implementations of FirebaseCore.
  ///
  /// Ported from FirebaseCore/Tests/Unit/FIRSceneFinderTests.m. Instead of OCMock class mocks of
  /// `UIApplication`, `UIScene`, `UIWindowScene` and `UIWindow`, the tests pass plain `NSObject`
  /// fakes that implement the few messages SceneFinder sends: `connectedScenes`,
  /// `activationState`, `delegate`, `isKindOfClass:`, `windows` and `isKeyWindow`. SceneFinder only
  /// sends Objective-C messages to these objects, which holds for a Swift implementation too,
  /// because UIKit's properties are dispatched through the Objective-C runtime. The test code
  /// itself never calls a UIKit method on a fake.
  ///
  /// `connectedScenes` is an `NSSet`, so its order isn't defined. The fake application returns an
  /// `OrderedTestSet`, which enumerates in a chosen order, and each case runs with every order of
  /// its scenes, so no test passes because of a lucky order.
  @MainActor
  final class SceneFinderTests: XCTestCase {
    private let selector = NSSelectorFromString("scene:continueUserActivity:")

    // MARK: - findForegroundSceneForApplication:matchingSelector:

    func testNilApplicationReturnsNil() {
      XCTAssertNil(SceneFinder.findForegroundScene(for: nil, matching: selector))
    }

    func testNilSelectorReturnsNil() {
      // New: Swift can't pass a nil selector, so this calls the method's implementation directly.
      typealias Function = @convention(c) (AnyObject, Selector, AnyObject?, Selector?)
        -> Unmanaged<AnyObject>?
      let methodSelector =
        NSSelectorFromString("findForegroundSceneForApplication:matchingSelector:")
      guard let method = class_getClassMethod(SceneFinder.self, methodSelector) else {
        return XCTFail("SceneFinder doesn't implement \(methodSelector)")
      }
      let function = unsafeBitCast(method_getImplementation(method), to: Function.self)
      let application = FakeApplication([makeScene(.foregroundActive)])

      let result = function(SceneFinder.self as AnyObject, methodSelector, application, nil)

      XCTAssertNil(result)
    }

    func testNoMatchingScene() {
      // The delegate doesn't respond to the selector.
      let scene = makeScene(.foregroundActive, delegate: NonRespondingSceneDelegate())
      assertFinds(nil, among: [scene], using: .selector(selector))
    }

    func testNilDelegateDoesNotMatch() {
      // New.
      let scene = makeScene(.foregroundActive, delegate: nil)
      assertFinds(nil, among: [scene], using: .selector(selector))
    }

    func testDelegateMustRespondToTheSelector() {
      // New: only scenes whose delegate responds are considered, even if a better scene doesn't.
      let responding = makeScene(.foregroundInactive)
      let nonResponding = makeScene(.foregroundActive, keyWindow: true,
                                    delegate: NonRespondingSceneDelegate())
      assertFinds(responding, among: [responding, nonResponding], using: .selector(selector))
    }

    func testForegroundInactiveFallback() {
      assertForegroundInactiveFallback(using: .selector(selector))
    }

    func testForegroundActivePriority() {
      assertForegroundActivePriority(using: .selector(selector))
    }

    func testActiveSceneWithKeyWindowPriority() {
      assertActiveSceneWithKeyWindowPriority(using: .selector(selector))
    }

    func testInactiveSceneWithKeyWindowPriority() {
      assertInactiveSceneWithKeyWindowPriority(using: .selector(selector))
    }

    func testActiveWithoutKeyWindowBeatsInactiveWithKeyWindow() {
      assertActiveWithoutKeyWindowBeatsInactiveWithKeyWindow(using: .selector(selector))
    }

    // MARK: - findForegroundWindowSceneForApplication:

    func testFindForegroundWindowSceneNilApplicationReturnsNil() {
      XCTAssertNil(SceneFinder.findForegroundWindowScene(for: nil))
    }

    func testFindForegroundWindowSceneIgnoresNonWindowScenes() {
      let scene = makeScene(.foregroundActive, isWindowScene: false)
      assertFinds(nil, among: [scene], using: .windowScene)

      // A window scene is found even when a better scene isn't a window scene.
      let windowScene = makeScene(.foregroundInactive)
      let nonWindowScene = makeScene(.foregroundActive, isWindowScene: false)
      assertFinds(windowScene, among: [windowScene, nonWindowScene], using: .windowScene)
    }

    func testFindForegroundWindowSceneForegroundInactiveFallback() {
      assertForegroundInactiveFallback(using: .windowScene)
    }

    func testFindForegroundWindowSceneForegroundActivePriority() {
      assertForegroundActivePriority(using: .windowScene)
    }

    func testFindForegroundWindowSceneActiveSceneWithKeyWindowPriority() {
      assertActiveSceneWithKeyWindowPriority(using: .windowScene)
    }

    func testFindForegroundWindowSceneInactiveSceneWithKeyWindowPriority() {
      assertInactiveSceneWithKeyWindowPriority(using: .windowScene)
    }

    func testFindForegroundWindowSceneActiveWithoutKeyWindowBeatsInactiveWithKeyWindow() {
      assertActiveWithoutKeyWindowBeatsInactiveWithKeyWindow(using: .windowScene)
    }

    // MARK: - findForegroundSceneForApplication:matchingPredicate:

    func testMatchingPredicateNilApplicationReturnsNil() {
      XCTAssertNil(SceneFinder.findForegroundScene(for: nil, matchingPredicate: { _ in true }))
    }

    func testMatchingPredicateNilPredicateReturnsNil() {
      // Swift can't pass a nil block, so this calls the method's implementation directly.
      typealias Function = @convention(c) (AnyObject, Selector, AnyObject?, AnyObject?)
        -> Unmanaged<AnyObject>?
      let methodSelector =
        NSSelectorFromString("findForegroundSceneForApplication:matchingPredicate:")
      guard let method = class_getClassMethod(SceneFinder.self, methodSelector) else {
        return XCTFail("SceneFinder doesn't implement \(methodSelector)")
      }
      let function = unsafeBitCast(method_getImplementation(method), to: Function.self)
      let application = FakeApplication([makeScene(.foregroundActive)])

      let result = function(SceneFinder.self as AnyObject, methodSelector, application, nil)

      XCTAssertNil(result)
    }

    func testMatchingPredicateFiltersNonMatchingScenes() {
      let scene = makeScene(.foregroundActive, keyWindow: true)
      assertFinds(nil, among: [scene], using: .predicate { _ in false })
    }

    func testMatchingPredicateForegroundInactiveFallback() {
      // The predicate matches only the inactive scene, so the active one isn't a candidate.
      let background = makeScene(.background)
      let inactive = makeScene(.foregroundInactive)
      let active = makeScene(.foregroundActive)
      assertFinds(inactive, among: [background, inactive, active],
                  using: .predicate { $0 !== active })
    }

    func testMatchingPredicateForegroundActivePriority() {
      assertForegroundActivePriority(using: .predicate { _ in true })
    }

    func testMatchingPredicateActiveSceneWithKeyWindowPriority() {
      assertActiveSceneWithKeyWindowPriority(using: .predicate { _ in true })
    }

    func testMatchingPredicateInactiveSceneWithKeyWindowPriority() {
      assertInactiveSceneWithKeyWindowPriority(using: .predicate { _ in true })
    }

    func testMatchingPredicateActiveWithoutKeyWindowBeatsInactiveWithKeyWindow() {
      assertActiveWithoutKeyWindowBeatsInactiveWithKeyWindow(using: .predicate { _ in true })
    }

    // MARK: - Edge cases (new)

    func testBackgroundAndUnattachedScenesAreIgnored() {
      for finder in Finder.all(selector: selector) {
        let background = makeScene(.background, keyWindow: true)
        let unattached = makeScene(.unattached, keyWindow: true)
        assertFinds(nil, among: [background, unattached], using: finder)

        let inactive = makeScene(.foregroundInactive)
        assertFinds(inactive, among: [background, unattached, inactive], using: finder)
      }
    }

    func testWindowSceneWithoutWindowsHasNoKeyWindow() {
      for finder in Finder.all(selector: selector) {
        let noWindows = makeScene(.foregroundActive, windows: [])
        let keyWindow = makeScene(.foregroundActive, keyWindow: true)
        assertFinds(keyWindow, among: [noWindows, keyWindow], using: finder)

        // A scene with no windows is still found.
        assertFinds(noWindows, among: [noWindows], using: finder)
      }
    }

    func testOnlyWindowScenesCanHaveAKeyWindow() {
      // A scene that isn't a window scene never counts as having a key window, and its `windows`
      // isn't read.
      let notWindowScene = makeScene(.foregroundActive, keyWindow: true, isWindowScene: false)
      let windowScene = makeScene(.foregroundActive, keyWindow: true)
      assertFinds(windowScene, among: [notWindowScene, windowScene],
                  using: .predicate { _ in true })
      XCTAssertEqual(notWindowScene.windowsReads, 0)

      let inactiveKey = makeScene(.foregroundInactive, keyWindow: true)
      let inactiveNotWindowScene = makeScene(.foregroundInactive, keyWindow: true,
                                             isWindowScene: false)
      assertFinds(inactiveKey, among: [inactiveNotWindowScene, inactiveKey],
                  using: .predicate { _ in true })
      XCTAssertEqual(inactiveNotWindowScene.windowsReads, 0)
    }

    func testAnyKeyWindowMakesTheSceneKey() {
      let window = FakeWindow(isKeyWindow: false)
      let keyWindow = FakeWindow(isKeyWindow: true)
      let lastWindowKey = makeScene(.foregroundInactive, windows: [window, keyWindow])
      let noKey = makeScene(.foregroundInactive, windows: [FakeWindow(isKeyWindow: false)])
      assertFinds(lastWindowKey, among: [noKey, lastWindowKey], using: .predicate { _ in true })
    }

    func testFullPriorityOrder() {
      // Active with a key window, then active, then inactive with a key window, then inactive.
      // Background and unattached scenes are never found.
      let ranked = [
        makeScene(.foregroundActive, keyWindow: true),
        makeScene(.foregroundActive),
        makeScene(.foregroundInactive, keyWindow: true),
        makeScene(.foregroundInactive),
      ]
      let ignored = [makeScene(.background, keyWindow: true), makeScene(.unattached)]
      for finder in Finder.all(selector: selector) {
        for index in ranked.indices {
          assertFinds(ranked[index], among: Array(ranked[index...]) + ignored, using: finder)
        }
      }
    }

    func testFirstMatchWinsAmongEquals() {
      // Among scenes with the same activation state and key window status, SceneFinder returns
      // the first one that `connectedScenes` enumerates. UIKit doesn't define that order, so
      // callers can't rely on which of several equal scenes they get, only that it's one of them.
      let tiers: [(UIScene.ActivationState, Bool)] = [
        (.foregroundActive, true), (.foregroundActive, false),
        (.foregroundInactive, true), (.foregroundInactive, false),
      ]
      for (state, isKey) in tiers {
        let first = makeScene(state, keyWindow: isKey)
        let second = makeScene(state, keyWindow: isKey)
        for finder in Finder.all(selector: selector) {
          XCTAssertTrue(find([first, second], using: finder) === first, "\(state) \(isKey)")
          XCTAssertTrue(find([second, first], using: finder) === second, "\(state) \(isKey)")
        }
      }
    }

    // MARK: - The fakes

    func testFakesMatchUIKitTypeEncodings() throws {
      // SceneFinder sends these messages to the fakes, so the fakes' methods must take and return
      // the same types as UIKit's, such as NSInteger for `activationState`.
      let pairs: [(fake: AnyClass, real: AnyClass, selector: String)] = [
        (FakeApplication.self, UIApplication.self, "connectedScenes"),
        (FakeScene.self, UIScene.self, "activationState"),
        (FakeScene.self, UIScene.self, "delegate"),
        (FakeScene.self, UIWindowScene.self, "windows"),
        (FakeWindow.self, UIWindow.self, "isKeyWindow"),
      ]
      for pair in pairs {
        let fakeEncoding = try methodEncoding(pair.fake, pair.selector)
        let realEncoding = try methodEncoding(pair.real, pair.selector)
        XCTAssertEqual(fakeEncoding, realEncoding, pair.selector)
      }
      XCTAssertEqual(try methodEncoding(FakeScene.self, "activationState"), "q@:")
    }

    func testFakeSceneClassChecks() {
      let windowScene = makeScene(.foregroundActive)
      XCTAssertTrue(windowScene.isKind(of: UIWindowScene.self))
      XCTAssertTrue(windowScene.isKind(of: UIScene.self))
      XCTAssertTrue(windowScene.isKind(of: NSObject.self))

      let scene = makeScene(.foregroundActive, isWindowScene: false)
      XCTAssertFalse(scene.isKind(of: UIWindowScene.self))
      XCTAssertTrue(scene.isKind(of: UIScene.self))
    }

    func testOrderedTestSetEnumeratesInOrder() {
      let scenes: [NSObject] = (0 ..< 5).map { _ in makeScene(.foregroundActive) }
      let set = OrderedTestSet(orderedObjects: scenes)
      XCTAssertEqual(set.count, 5)
      XCTAssertTrue(set.member(scenes[2]) as AnyObject? === scenes[2])
      XCTAssertTrue(set.copy() as AnyObject === set)

      // Objective-C fast enumeration, which FIRSceneFinder.m uses.
      var enumerated: [NSObject] = []
      for element in set {
        if let object = element as? NSObject {
          enumerated.append(object)
        }
      }
      XCTAssertTrue(enumerated.elementsEqual(scenes, by: ===))
      XCTAssertTrue(set.objectEnumerator().allObjects.elementsEqual(scenes) {
        ($0 as AnyObject) === $1
      })

      // A Swift `Set` bridged from it, which a Swift implementation would iterate.
      let bridged = set as Set<NSObject>
      XCTAssertTrue(bridged.elementsEqual(scenes, by: ===))
    }

    // MARK: - Shared scenarios

    private func assertForegroundInactiveFallback(using finder: Finder,
                                                  line: UInt = #line) {
      let background = makeScene(.background)
      let inactive = makeScene(.foregroundInactive)
      assertFinds(inactive, among: [background, inactive], using: finder, line: line)
    }

    private func assertForegroundActivePriority(using finder: Finder, line: UInt = #line) {
      let inactive = makeScene(.foregroundInactive)
      let active = makeScene(.foregroundActive)
      assertFinds(active, among: [inactive, active], using: finder, line: line)
    }

    private func assertActiveSceneWithKeyWindowPriority(using finder: Finder,
                                                        line: UInt = #line) {
      let active = makeScene(.foregroundActive, keyWindow: false)
      let activeKey = makeScene(.foregroundActive, keyWindow: true)
      assertFinds(activeKey, among: [active, activeKey], using: finder, line: line)
    }

    private func assertInactiveSceneWithKeyWindowPriority(using finder: Finder,
                                                          line: UInt = #line) {
      let inactive = makeScene(.foregroundInactive, keyWindow: false)
      let inactiveKey = makeScene(.foregroundInactive, keyWindow: true)
      assertFinds(inactiveKey, among: [inactive, inactiveKey], using: finder, line: line)
    }

    private func assertActiveWithoutKeyWindowBeatsInactiveWithKeyWindow(using finder: Finder,
                                                                        line: UInt = #line) {
      let active = makeScene(.foregroundActive, keyWindow: false)
      let inactiveKey = makeScene(.foregroundInactive, keyWindow: true)
      assertFinds(active, among: [active, inactiveKey], using: finder, line: line)
    }

    // MARK: - Helpers

    /// One of SceneFinder's three methods.
    enum Finder {
      case selector(Selector)
      case windowScene
      case predicate((UIScene) -> Bool)

      static func all(selector: Selector) -> [Finder] {
        [.selector(selector), .windowScene, .predicate { _ in true }]
      }
    }

    /// Creates a scene. By default it's a window scene with one window, which is key when
    /// `keyWindow` is true, and its delegate responds to `scene:continueUserActivity:`, so the
    /// scene qualifies for all three methods.
    private func makeScene(_ state: UIScene.ActivationState,
                           keyWindow: Bool = false,
                           windows: [FakeWindow]? = nil,
                           isWindowScene: Bool = true,
                           delegate: NSObject? = RespondingSceneDelegate()) -> FakeScene {
      FakeScene(activationState: state,
                windows: windows ?? [FakeWindow(isKeyWindow: keyWindow)],
                isWindowScene: isWindowScene,
                delegate: delegate)
    }

    /// Runs `finder` on an application whose `connectedScenes` enumerates `scenes` in order.
    private func find(_ scenes: [FakeScene], using finder: Finder) -> AnyObject? {
      let application = FakeApplication(scenes)
      // The fake is passed where SceneFinder expects a UIApplication. SceneFinder only sends it
      // `connectedScenes`.
      let uiApplication = unsafeBitCast(application, to: UIApplication.self)
      return withExtendedLifetime(application) {
        switch finder {
        case let .selector(selector):
          return SceneFinder.findForegroundScene(for: uiApplication, matching: selector)
        case .windowScene:
          return SceneFinder.findForegroundWindowScene(for: uiApplication)
        case let .predicate(predicate):
          return SceneFinder.findForegroundScene(for: uiApplication, matchingPredicate: predicate)
        }
      }
    }

    /// Checks that `finder` returns `expected` for every order of `scenes`.
    private func assertFinds(_ expected: FakeScene?, among scenes: [FakeScene],
                             using finder: Finder, line: UInt = #line) {
      for order in permutations(of: scenes) {
        let result = find(order, using: finder)
        let position = order.firstIndex { $0 === expected }.map { "at \($0)" } ?? "absent"
        XCTAssertTrue(result === expected,
                      "\(finder) found \(String(describing: result)), expected scene \(position)",
                      line: line)
      }
    }

    private func permutations<T>(of elements: [T]) -> [[T]] {
      guard elements.count > 1 else { return [elements] }
      return elements.indices.flatMap { index -> [[T]] in
        var rest = elements
        let element = rest.remove(at: index)
        return permutations(of: rest).map { [element] + $0 }
      }
    }

    /// The Objective-C type encoding of an instance method, without stack offsets.
    private func methodEncoding(_ klass: AnyClass, _ selectorName: String) throws -> String {
      let method = try XCTUnwrap(class_getInstanceMethod(klass, NSSelectorFromString(selectorName)),
                                 "\(klass) doesn't implement \(selectorName)")
      let encoding = try XCTUnwrap(method_getTypeEncoding(method))
      return String(cString: encoding).filter { !$0.isNumber }
    }
  }

  // MARK: - Fakes

  /// Stands in for `UIApplication`. SceneFinder only reads `connectedScenes`.
  final class FakeApplication: NSObject {
    private let scenes: [NSObject]

    init(_ scenes: [NSObject]) {
      self.scenes = scenes
    }

    /// The scenes, enumerated in the order they were given.
    @objc var connectedScenes: NSSet {
      OrderedTestSet(orderedObjects: scenes)
    }
  }

  /// Stands in for `UIScene` or `UIWindowScene`.
  final class FakeScene: NSObject {
    @objc let activationState: UIScene.ActivationState
    @objc let delegate: NSObject?
    private let windowList: [FakeWindow]
    private let isWindowScene: Bool

    /// The number of times SceneFinder read `windows`.
    private(set) var windowsReads = 0

    init(activationState: UIScene.ActivationState, windows: [FakeWindow], isWindowScene: Bool,
         delegate: NSObject?) {
      self.activationState = activationState
      windowList = windows
      self.isWindowScene = isWindowScene
      self.delegate = delegate
    }

    @objc var windows: [FakeWindow] {
      windowsReads += 1
      return windowList
    }

    /// A `UIScene`, and a `UIWindowScene` if configured as one.
    override func isKind(of aClass: AnyClass) -> Bool {
      if ObjectIdentifier(aClass) == ObjectIdentifier(UIWindowScene.self) {
        return isWindowScene
      }
      if ObjectIdentifier(aClass) == ObjectIdentifier(UIScene.self) {
        return true
      }
      return super.isKind(of: aClass)
    }
  }

  /// Stands in for `UIWindow`. SceneFinder only reads `isKeyWindow`.
  final class FakeWindow: NSObject {
    @objc let isKeyWindow: Bool

    init(isKeyWindow: Bool) {
      self.isKeyWindow = isKeyWindow
    }
  }

  /// A scene delegate that responds to `scene:continueUserActivity:`.
  final class RespondingSceneDelegate: NSObject {
    @objc(scene:continueUserActivity:)
    func scene(_ scene: NSObject, continue userActivity: NSUserActivity) {}
  }

  /// A scene delegate that doesn't respond to `scene:continueUserActivity:`.
  final class NonRespondingSceneDelegate: NSObject {}

#endif // os(iOS) || os(tvOS) || os(visionOS)
