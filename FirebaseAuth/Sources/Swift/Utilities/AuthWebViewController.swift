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

  /// Defines a delegate for AuthWebViewController
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  protocol AuthWebViewControllerDelegate: AnyObject {
    /// Notifies the delegate that the web view controller is being cancelled by the user.
    /// - Parameter webViewController: The web view controller in question.
    func webViewControllerDidCancel(_ controller: AuthWebViewController)

    /// Determines if a URL should be handled by the delegate.
    /// - Parameter url: The URL to handle.
    /// - Returns: Whether the URL could be handled or not.
    func webViewController(_ controller: AuthWebViewController, canHandle url: URL) -> Bool

    /// Notifies the delegate that the web view controller failed to load a page.
    /// - Parameter webViewController: The web view controller in question.
    /// - Parameter error: The error that has occurred.
    func webViewController(_ controller: AuthWebViewController, didFailWithError error: Error)

    /// Presents an URL to interact with user.
    /// - Parameter url: The URL to present.
    /// - Parameter uiDelegate: The UI delegate to present view controller.
    /// - Parameter completion: A block to be called either synchronously if the presentation fails
    /// to start, or asynchronously in future on an unspecified thread once the presentation
    /// finishes.
    func present(_ url: URL,
                 uiDelegate: AuthUIDelegate?,
                 callbackMatcher: @escaping (URL?) -> Bool,
                 completion: @escaping (URL?, Error?) -> Void)
  }

  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  class AuthWebViewController: UIViewController,
    WKNavigationDelegate {
    // MARK: - Properties

    private var url: URL
    weak var delegate: AuthWebViewControllerDelegate?
    private weak var webView: AuthWebView?

    // MARK: - Initialization

    init(url: URL, delegate: AuthWebViewControllerDelegate) {
      self.url = url
      self.delegate = delegate
      super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }

    // MARK: - View Lifecycle

    override func loadView() {
      let webView = AuthWebView(frame: UIScreen.main.bounds)
      webView.webView.navigationDelegate = self
      view = webView
      self.webView = webView
      navigationItem.leftBarButtonItem = UIBarButtonItem(
        barButtonSystemItem: .cancel,
        target: self,
        action: #selector(cancel)
      )
    }

    override func viewDidAppear(_ animated: Bool) {
      super.viewDidAppear(animated)
      webView?.webView.load(URLRequest(url: url))
    }

    // MARK: - Actions

    @objc private func cancel() {
      delegate?.webViewControllerDidCancel(self)
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction) async
      -> WKNavigationActionPolicy {
      _ = delegate?.webViewController(
        self,
        canHandle: navigationAction.request.url ?? url
      )
      return .allow
    }

    func webView(_ webView: WKWebView,
                 didStartProvisionalNavigation navigation: WKNavigation!) {
      self.webView?.spinner.isHidden = false
      self.webView?.spinner.startAnimating()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
      self.webView?.spinner.isHidden = true
      self.webView?.spinner.stopAnimating()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!,
                 withError error: Error) {
      if (error as NSError).domain == NSURLErrorDomain,
         (error as NSError).code == NSURLErrorCancelled {
        // It's okay for the page to be redirected before it is completely loaded.  See b/32028062 .
        return
      }
      // Forward notification to our delegate.
      self.webView(webView, didFinish: navigation)
      delegate?.webViewController(self, didFailWithError: error)
    }
  }
#endif
