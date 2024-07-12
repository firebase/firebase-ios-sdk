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

  import UIKit
  import WebKit

  /// A class responsible for creating a WKWebView for use within Firebase Auth.
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  class AuthWebView: UIView {
    lazy var webView: WKWebView = createWebView()
    lazy var spinner: UIActivityIndicatorView = createSpinner()

    override init(frame: CGRect) {
      super.init(frame: frame)
      backgroundColor = .white
      initializeSubviews()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }

    private func initializeSubviews() {
      let webView = createWebView()
      let spinner = createSpinner()

      // The order of the following controls z-order.
      addSubview(webView)
      addSubview(spinner)

      layoutSubviews()
      self.webView = webView
      self.spinner = spinner
    }

    override func layoutSubviews() {
      super.layoutSubviews()
      let height = bounds.size.height
      let width = bounds.size.width
      webView.frame = CGRect(x: 0, y: 0, width: width, height: height)
      spinner.center = webView.center
    }

    private func createWebView() -> WKWebView {
      let webView = WKWebView(frame: .zero)
      // Trickery to make the web view not do weird things (like showing a black background when
      // the prompt in the navigation bar animates changes.)
      webView.isOpaque = false
      webView.backgroundColor = .clear
      webView.scrollView.isOpaque = false
      webView.scrollView.backgroundColor = .clear
      webView.scrollView.bounces = false
      webView.scrollView.alwaysBounceVertical = false
      webView.scrollView.alwaysBounceHorizontal = false
      return webView
    }

    private func createSpinner() -> UIActivityIndicatorView {
      return UIActivityIndicatorView(style: .medium)
    }
  }
#endif
