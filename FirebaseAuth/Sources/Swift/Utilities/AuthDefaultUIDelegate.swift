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

#if os(iOS) || os(tvOS)

  import Foundation
  import UIKit
  #if COCOAPODS
    internal import GoogleUtilities
  #else
    internal import GoogleUtilities_Environment
  #endif

  /// Class responsible for providing a default AuthUIDelegate.
  ///
  /// This class should be used in the case that a UIDelegate was expected and necessary to
  /// continue a given flow, but none was provided.
  final class AuthDefaultUIDelegate: NSObject, AuthUIDelegate {
    /// Returns a default AuthUIDelegate object.
    /// - Returns: The default AuthUIDelegate object.
    @MainActor static func defaultUIDelegate() -> AuthUIDelegate? {
      if GULAppEnvironmentUtil.isAppExtension() {
        // iOS App extensions should not call [UIApplication sharedApplication], even if
        // UIApplication responds to it.
        return nil
      }

      // Using reflection here to avoid build errors in extensions.
      let sel = NSSelectorFromString("sharedApplication")
      guard UIApplication.responds(to: sel),
            let rawApplication = UIApplication.perform(sel),
            let application = rawApplication.takeUnretainedValue() as? UIApplication else {
        return nil
      }
      var topViewController: UIViewController?
      if #available(iOS 13.0, tvOS 13.0, *) {
        let connectedScenes = application.connectedScenes
        for scene in connectedScenes {
          if let windowScene = scene as? UIWindowScene {
            for window in windowScene.windows {
              if window.isKeyWindow {
                topViewController = window.rootViewController
              }
            }
          }
        }
      } else {
        topViewController = application.keyWindow?.rootViewController
      }
      while true {
        if let controller = topViewController?.presentedViewController {
          topViewController = controller
        } else if let navController = topViewController as? UINavigationController {
          topViewController = navController.topViewController
        } else if let tabBarController = topViewController as? UITabBarController {
          topViewController = tabBarController.selectedViewController
        } else {
          break
        }
      }
      return AuthDefaultUIDelegate(withViewController: topViewController)
    }

    init(withViewController viewController: UIViewController?) {
      self.viewController = viewController
    }

    func present(_ viewControllerToPresent: UIViewController, animated flag: Bool,
                 completion: (() -> Void)? = nil) {
      viewController?.present(viewControllerToPresent, animated: flag, completion: completion)
    }

    public func dismiss(completion: (() -> Void)?) {
    // Store a reference to the window so we can close it after the view controller is dismissed
    let window = currentWebWindow
    currentWebWindow = nil
    
    // Close the window
    DispatchQueue.main.async {
      window?.close()
      completion?()
    }
  }

    private let viewController: UIViewController?
  }

#elseif os(macOS)

  import Foundation
  import AppKit
  #if COCOAPODS
    internal import GoogleUtilities
  #else
    internal import GoogleUtilities_Environment
  #endif

  /// Custom window class for OAuth flow
  final class AuthWebWindow: NSWindow {
    weak var authViewController: NSViewController?
    
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
      super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
      setupWindow()
    }
    
    private func setupWindow() {
      title = "Sign In"
      isReleasedWhenClosed = false
      center()
      level = .floating
      styleMask = [.titled, .closable, .miniaturizable, .resizable]
    }
    
    override func performClose(_ sender: Any?) {
      // Notify the auth view controller that user canceled
      if let authVC = authViewController as? AuthWebViewController {
        authVC.handleWindowClose()
      }
      super.performClose(sender)
    }
  }

  /// Class responsible for providing a default AuthUIDelegate.
  ///
  /// This class should be used in the case that a UIDelegate was expected and necessary to
  /// continue a given flow, but none was provided.
  final class AuthDefaultUIDelegate: NSObject, AuthUIDelegate {
    private var authWindow: AuthWebWindow?
    
    /// Returns a default AuthUIDelegate object.
    /// - Returns: The default AuthUIDelegate object.
    @MainActor static func defaultUIDelegate() -> AuthUIDelegate? {
      if GULAppEnvironmentUtil.isAppExtension() {
        // macOS App extensions should not access NSApplication.shared.
        return nil
      }
      
      return AuthDefaultUIDelegate()
    }

    func present(_ viewControllerToPresent: NSViewController,
                 completion: (() -> Void)? = nil) {
      // Create a new window for the OAuth flow
      let windowRect = NSRect(x: 0, y: 0, width: 800, height: 600)
      authWindow = AuthWebWindow(
        contentRect: windowRect,
        styleMask: [.titled, .closable, .miniaturizable, .resizable],
        backing: .buffered,
        defer: false
      )
      
      authWindow?.authViewController = viewControllerToPresent
      authWindow?.contentViewController = viewControllerToPresent
      authWindow?.makeKeyAndOrderFront(nil)
      
      completion?()
    }

    func dismiss(completion: (() -> Void)? = nil) {
      authWindow?.close()
      authWindow = nil
      completion?()
    }
  }

#endif
