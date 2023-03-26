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

@objc(FIRAuthWebView) public class AuthWebView: UIView {

    public lazy var webView: WKWebView = createWebView()
    public lazy var spinner: UIActivityIndicatorView = createSpinner()

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = .white
        self.initializeSubviews()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func initializeSubviews() {
        let webView = self.createWebView()
        let spinner = self.createSpinner()

        // The order of the following controls z-order.
        self.addSubview(webView)
        self.addSubview(spinner)

        self.layoutSubviews()
        self.webView = webView
        self.spinner = spinner
    }

  // TODO: Should not be public

  public override func layoutSubviews() {
        super.layoutSubviews()
        let height = self.bounds.size.height
        let width = self.bounds.size.width
        self.webView.frame = CGRect(x: 0, y: 0, width: width, height: height)
        self.spinner.center = self.webView.center
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
      var spinnerStyle: UIActivityIndicatorView.Style = .gray
      #if targetEnvironment(macCatalyst)
      if #available(iOS 13.0, *) {
          spinnerStyle = .medium
      } else {
          // iOS 13 deprecation
  //            #pragma clang diagnostic push
  //            #pragma clang diagnostic ignored "-Wdeprecated-declarations"
          spinnerStyle = .gray
  //            #pragma clang diagnostic pop
      }
      #endif
      let spinner = UIActivityIndicatorView(style: spinnerStyle)
      return spinner
  }
}

#endif
