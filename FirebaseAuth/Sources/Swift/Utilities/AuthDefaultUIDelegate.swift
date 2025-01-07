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
    @_implementationOnly import GoogleUtilities
  #else
    @_implementationOnly import GoogleUtilities_Environment
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

    func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
      viewController?.dismiss(animated: flag, completion: completion)
    }

    private let viewController: UIViewController?
  }
#endif
