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

#if os(iOS) || os(tvOS) || os(visionOS)

  import Foundation
  import UIKit

  /// A protocol to handle user interface interactions for Firebase Auth.
  ///
  /// This protocol is available on iOS, macOS Catalyst, and tvOS only.
  @objc(FIRAuthUIDelegate) public protocol AuthUIDelegate: NSObjectProtocol {
    /// If implemented, this method will be invoked when Firebase Auth needs to display a view
    /// controller.
    /// - Parameter viewControllerToPresent: The view controller to be presented.
    /// - Parameter flag: Decides whether the view controller presentation should be animated.
    /// - Parameter completion: The block to execute after the presentation finishes.
    /// This block has no return value and takes no parameters.
    @objc(presentViewController:animated:completion:)
    func present(_ viewControllerToPresent: UIViewController,
                 animated flag: Bool,
                 completion: (() -> Void)?)

    /// If implemented, this method will be invoked when Firebase Auth needs to display a view
    /// controller.
    /// - Parameter flag: Decides whether removing the view controller should be animated or not.
    /// - Parameter completion: The block to execute after the presentation finishes.
    /// This block has no return value and takes no parameters.
    @objc(dismissViewControllerAnimated:completion:)
    func dismiss(animated flag: Bool, completion: (() -> Void)?)
  }

  // Extension to support default argument variations.
  extension AuthUIDelegate {
    func present(_ viewControllerToPresent: UIViewController,
                 animated flag: Bool,
                 completion: (() -> Void)? = nil) {
      return present(viewControllerToPresent, animated: flag, completion: nil)
    }

    func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
      return dismiss(animated: flag, completion: nil)
    }
  }
#endif
