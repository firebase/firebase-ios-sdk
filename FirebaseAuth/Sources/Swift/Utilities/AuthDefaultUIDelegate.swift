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
  @_implementationOnly import GoogleUtilities

  /** @class AuthDefaultUIDelegate
      @brief Class responsible for providing a default FIRAuthUIDelegte.
      @remarks This class should be used in the case that a UIDelegate was expected and necessary to
          continue a given flow, but none was provided.
   */
  class AuthDefaultUIDelegate: NSObject, AuthUIDelegate {
    // TODO: Figure out what to do for extensions.
    /** @fn defaultUIDelegate
        @brief Returns a default FIRAuthUIDelegate object.
        @return The default FIRAuthUIDelegate object.
     */
    @available(iOSApplicationExtension, unavailable)
    @available(tvOSApplicationExtension, unavailable)
    class func defaultUIDelegate() -> AuthUIDelegate? {
      // iOS App extensions should not call [UIApplication sharedApplication], even if UIApplication
      // responds to it.
      guard let applicationClass = NSClassFromString("UIApplication"),
            applicationClass.responds(to: NSSelectorFromString("sharedApplication")) else {
        return nil
      }
      var topViewController: UIViewController?
      if #available(iOS 13.0, tvOS 13.0, *) {
        let connectedScenes = UIApplication.shared.connectedScenes
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
        topViewController = UIApplication.shared.keyWindow?.rootViewController
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
