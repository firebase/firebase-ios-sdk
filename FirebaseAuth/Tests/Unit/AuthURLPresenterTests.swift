// Copyright 2023 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License")
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

#if os(iOS)

  import Foundation
  import XCTest

  @testable import FirebaseAuth
  import FirebaseCore
  import SafariServices

  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  class AuthURLPresenterTests: XCTestCase {
    /** @fn testFIRAuthURLPresenterNonNilUIDelegate
        @brief Tests @c FIRAuthURLPresenter class showing UI with a non-nil UIDelegate.
     */
    func testAuthURLPresenterNonNilUIDelegate() throws {
      try internalAuthURLPresenterTests(useDefaultUIDelegate: false)
    }

    /** @fn testFIRAuthURLPresenterNilUIDelegate
        @brief Tests @c FIRAuthURLPresenter class showing UI with a nil UIDelegate.
     */
    func testFIRAuthURLPresenterNilUIDelegate() throws {
      try internalAuthURLPresenterTests(useDefaultUIDelegate: true)
    }

    private func internalAuthURLPresenterTests(useDefaultUIDelegate: Bool) throws {
      let presenterExpectation = expectation(description: "presentation expectation")
      let presenter = AuthURLPresenter()
      presenter.fakeUIDelegate = FakeUIDelegate(presenter, presenterExpectation)

      let presenterURL = try XCTUnwrap(URL(string: "https://presenter.url"))
      let uiDelegate = useDefaultUIDelegate ? AuthDefaultUIDelegate(withViewController: nil) : nil

      let callbackMatcherExpectation = expectation(description: "callback matcher expectation")
      let callbackMatcher: (URL?) -> Bool = { callbackURL in
        XCTAssertEqual(callbackURL, presenterURL)
        callbackMatcherExpectation.fulfill()
        return true
      }

      let completionExpectation = expectation(description: "completion expectation")
      let completion: (URL?, Error?) -> Void = { callbackURL, error in
        XCTAssertEqual(callbackURL, presenterURL)
        XCTAssertNil(error)
        completionExpectation.fulfill()
      }

      // Present the content.
      presenter.present(presenterURL,
                        uiDelegate: uiDelegate,
                        callbackMatcher: callbackMatcher,
                        completion: completion)

      // Close the presented content and trigger callbacks.
      XCTAssertTrue(presenter.canHandle(url: presenterURL))

      waitForExpectations(timeout: 5)

      class FakeUIDelegate: NSObject, AuthUIDelegate {
        func present(_ viewControllerToPresent: UIViewController,
                     animated flag: Bool,
                     completion: (() -> Void)? = nil) {
          #if targetEnvironment(macCatalyst)
            let navigationController = viewControllerToPresent as? UINavigationController
            let webViewController = navigationController?.viewControllers
              .first as? AuthWebViewController
            let delegate = webViewController?.delegate as? AuthURLPresenter
          #else
            let safariViewController = viewControllerToPresent as? SFSafariViewController
            let delegate = safariViewController?.delegate as? AuthURLPresenter
          #endif
          XCTAssertEqual(delegate, presenter)
          presenterExpectation.fulfill()
        }

        func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
          XCTFail("implement me")
        }

        init(_ presenter: AuthURLPresenter, _ expectation: XCTestExpectation) {
          self.presenter = presenter
          presenterExpectation = expectation
        }

        let presenter: AuthURLPresenter
        let presenterExpectation: XCTestExpectation
      }
    }
  }
#endif
