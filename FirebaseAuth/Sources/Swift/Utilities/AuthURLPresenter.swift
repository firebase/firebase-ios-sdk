// Copyright 2023 Google LLC
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

#if os(iOS)

  import Foundation
  import UIKit
  import WebKit
  import SafariServices

  // TODO: Remove objc's and publics

  /** @class AuthURLPresenter
      @brief A Class responsible for presenting URL via SFSafariViewController or WKWebView.
   */
  @objc(FIRAuthURLPresenter) public class AuthURLPresenter: NSObject,
    SFSafariViewControllerDelegate,
    FIRAuthWebViewControllerDelegate {
    /** @fn
        @brief Presents an URL to interact with user.
        @param URL The URL to present.
        @param UIDelegate The UI delegate to present view controller.
        @param completion A block to be called either synchronously if the presentation fails to start,
            or asynchronously in future on an unspecified thread once the presentation finishes.
     */
    @objc(presentURL:UIDelegate:callbackMatcher:completion:) public
    func present(_ url: URL,
                 uiDelegate: AuthUIDelegate?,
                 callbackMatcher: @escaping (URL?) -> Bool,
                 completion: @escaping (URL?, Error?) -> Void) {
      if isPresenting {
        // Unable to start a new presentation on top of another.
        // Invoke the new completion closure and leave the old one as-is
        // to be invoked when the presentation finishes.
        DispatchQueue.main.async {
          completion(nil, AuthErrorUtils.webContextCancelledError(message: nil))
        }
        return
      }
      isPresenting = true
      self.callbackMatcher = callbackMatcher
      self.completion = completion
      DispatchQueue.main.async {
        // TODO: Next line after AuthDefaultUIDelegate
        self.uiDelegate = uiDelegate // ?? FIRAuthDefaultUIDelegate.defaultUIDelegate()
        #if targetEnvironment(macCatalyst)
          self.webViewController = AuthWebViewController(url: url, delegate: self)
          if let webViewController = self.webViewController {
            let navController = UINavigationController(rootViewController: webViewController)
            self.uiDelegate?.present(navController, animated: true)
          }
        #else
          self.safariViewController = SFSafariViewController(url: url)
          self.safariViewController?.delegate = self
          if let safariViewController = self.safariViewController {
            self.uiDelegate?.present(safariViewController, animated: true)
          }
        #endif
      }
    }

    /** @fn canHandleURL:
        @brief Determines if a URL was produced by the currently presented URL.
        @param URL The URL to handle.
        @return Whether the URL could be handled or not.
     */
    @objc(canHandleURL:) public func canHandle(url: URL) -> Bool {
      if isPresenting,
         let callbackMatcher = callbackMatcher,
         callbackMatcher(url) {
        return true
      }
      return false
    }

    // MARK: AuthWebViewControllerDelegate

    public func webViewControllerDidCancel(_ controller: AuthWebViewController) {
      kAuthGlobalWorkQueue.async {
        if self.webViewController == controller {
          self.finishPresentation(withURL: nil,
                                  error: AuthErrorUtils.webContextCancelledError(message: nil))
        }
      }
    }

    public func webViewController(_ controller: AuthWebViewController, canHandle url: URL) -> Bool {
      var result = false
      kAuthGlobalWorkQueue.sync {
        if self.webViewController == controller {
          result = self.canHandle(url: url)
        }
      }
      return result
    }

    public func webViewController(_ controller: AuthWebViewController,
                                  didFailWithError error: Error) {
      kAuthGlobalWorkQueue.async {
        if self.webViewController == controller {
          self.finishPresentation(withURL: nil, error: error)
        }
      }
    }

    /** @var _isPresenting
        @brief Whether or not some web-based content is being presented.
            Accesses to this property are serialized on the global Auth work queue
            and thus this variable should not be read or written outside of the work queue.
     */
    private var isPresenting: Bool = false

    /** @var _callbackMatcher
        @brief The callback URL matcher for the current presentation, if one is active.
     */
    private var callbackMatcher: ((URL) -> Bool)?

    /** @var _safariViewController
        @brief The SFSafariViewController used for the current presentation, if any.
     */
    private var safariViewController: SFSafariViewController?

    /** @var _webViewController
        @brief The FIRAuthWebViewController used for the current presentation, if any.
     */
    private var webViewController: AuthWebViewController?

    /** @var _UIDelegate
        @brief The UIDelegate used to present the SFSafariViewController.
     */
    private var uiDelegate: AuthUIDelegate?

    /** @var _completion
        @brief The completion handler for the current presentation, if one is active.
            Accesses to this variable are serialized on the global Auth work queue
            and thus this variable should not be read or written outside of the work queue.
        @remarks This variable is also used as a flag to indicate a presentation is active.
     */
    private var completion: ((URL?, Error?) -> Void)?

    // MARK: Private methods

    private func finishPresentation(withURL url: URL?, error: Error?) {
      callbackMatcher = nil
      let uiDelegate = self.uiDelegate
      self.uiDelegate = nil
      let completion = self.completion
      self.completion = nil
      let safariViewController = self.safariViewController
      self.safariViewController = nil
      let webViewController = self.webViewController
      self.webViewController = nil
      if safariViewController != nil || webViewController != nil {
        uiDelegate?.dismiss(animated: true) {
          kAuthGlobalWorkQueue.async {
            self.isPresenting = false
            if let completion {
              completion(url, error)
            }
          }
        }
      }
      isPresenting = false
      if let completion {
        completion(url, error)
      }
    }
  }
#endif
