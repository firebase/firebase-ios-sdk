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

import Foundation
import WebKit

#if os(iOS)
  import UIKit
#elseif os(macOS)
  import AppKit
#endif

#if os(iOS) || os(macOS)
  /// Defines a delegate for AuthWebViewController
  @available(iOS 13, macOS 10.15, *)
  protocol AuthWebViewControllerDelegate: AnyObject {
    /// Notifies the delegate that the web view controller is being cancelled by the user.
    /// - Parameter webViewController: The web view controller in question.
    func webViewControllerDidCancel(_ controller: AuthWebViewController)

    /// Determines if a URL should be handled by the delegate.
    /// - Parameter url: The URL to handle.
    /// - Returns: Whether the URL could be handled or not.
    func webViewController(_ controller: AuthWebViewController,
                           canHandle url: URL) -> Bool

    /// Notifies the delegate that the web view controller failed to load a page.
    /// - Parameter webViewController: The web view controller in question.
    /// - Parameter error: The error that has occurred.
    func webViewController(_ controller: AuthWebViewController,
                           didFailWithError error: Error)

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

#endif // os(iOS) || os(macOS)

#if os(iOS)
  class AuthWebViewController: UIViewController,
    WKNavigationDelegate {
    // MARK: - Properties

    private var url: URL
    weak var delegate: AuthWebViewControllerDelegate?

    private let webView: WKWebView = {
      let webView = WKWebView(frame: .zero)
      webView.isOpaque = false
      webView.backgroundColor = .clear
      webView.scrollView.isOpaque = false
      webView.scrollView.backgroundColor = .clear
      webView.scrollView.bounces = false
      webView.scrollView.alwaysBounceVertical = false
      webView.scrollView.alwaysBounceHorizontal = false
      return webView
    }()

    private let spinner = UIActivityIndicatorView(style: .medium)

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

    override func viewDidLoad() {
      super.viewDidLoad()
      view.backgroundColor = .white

      webView.navigationDelegate = self
      view.addSubview(webView)
      view.addSubview(spinner)

      navigationItem.leftBarButtonItem = UIBarButtonItem(
        barButtonSystemItem: .cancel,
        target: self,
        action: #selector(cancel)
      )
    }

    override func viewDidLayoutSubviews() {
      super.viewDidLayoutSubviews()
      webView.frame = view.bounds
      spinner.center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
    }

    override func viewDidAppear(_ animated: Bool) {
      super.viewDidAppear(animated)
      webView.load(URLRequest(url: url))
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
      spinner.isHidden = false
      spinner.startAnimating()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
      spinner.isHidden = true
      spinner.stopAnimating()
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

#elseif os(macOS)
  private final class AuthBackgroundView: NSView {
    override func viewDidChangeEffectiveAppearance() {
      super.viewDidChangeEffectiveAppearance()
      updateBackgroundColor()
    }

    func updateBackgroundColor() {
      wantsLayer = true

      effectiveAppearance.performAsCurrentDrawingAppearance {
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
      }
    }
  }

  @available(macOS 11.0, *)
  class AuthWebViewController: NSViewController,
    WKNavigationDelegate {
    // MARK: - Properties

    private var url: URL
    private var hasLoaded = false
    weak var delegate: AuthWebViewControllerDelegate?

    private let webView: WKWebView = {
      let webView = WKWebView(frame: .zero)
      webView.wantsLayer = true
      return webView
    }()

    private let spinner: NSProgressIndicator = {
      let spinner = NSProgressIndicator()
      spinner.style = .spinning
      spinner.isIndeterminate = true
      return spinner
    }()

    // MARK: - Initialization

    init(url: URL, delegate: AuthWebViewControllerDelegate) {
      self.url = url
      self.delegate = delegate
      super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }

    // MARK: - View Lifecycle

    override func loadView() {
      let backgroundView = AuthBackgroundView(
        frame: NSRect(x: 0, y: 0, width: 800, height: 600)
      )

      backgroundView.updateBackgroundColor()
      view = backgroundView

      webView.navigationDelegate = self

      view.addSubview(webView)
      view.addSubview(spinner)
    }

    override func viewDidLayout() {
      super.viewDidLayout()

      webView.frame = view.bounds
      spinner.frame = NSRect(
        x: view.bounds.midX - 16,
        y: view.bounds.midY - 16,
        width: 32,
        height: 32
      )
    }

    override func viewDidAppear() {
      super.viewDidAppear()

      guard !hasLoaded else { return }
      hasLoaded = true

      webView.load(URLRequest(url: url))
    }

    // MARK: - Public Methods

    func handleWindowClose() {
      // Called when user closes the window manually using standard macOS controls
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
      spinner.isHidden = false
      spinner.startAnimation(nil)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
      spinner.isHidden = true
      spinner.stopAnimation(nil)
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

    func webView(_ webView: WKWebView,
                 didFailProvisionalNavigation navigation: WKNavigation!,
                 withError error: Error) {
      self.webView(webView, didFail: navigation, withError: error)
    }
  }

#endif
