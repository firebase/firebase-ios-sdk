  // Copyright 2020 Google LLC
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

import UIKit

  /// Firebase Auth supported identity providers and other methods of authentication
enum MultiFactorMenu: String {
  case phoneEnroll
  case totpEnroll
  case multifactorUnenroll
  
    // More intuitively named getter for `rawValue`.
  var id: String { rawValue }
  
    // The UI friendly name of the `AuthMenu`. Used for display.
  var name: String {
    switch self {
        // Multi factor
    case .phoneEnroll:
      return "Phone Enroll"
    case .totpEnroll:
      return "TOTP Enroll"
    case .multifactorUnenroll:
      return "Multifactor unenroll"
    }
  }
  
    // Failable initializer to create an `AuthMenu` from its corresponding `name` value.
    // - Parameter rawValue: String value representing `AuthMenu`'s name or type.
  init?(rawValue: String) {
    switch rawValue {
    case "Phone Enroll":
      self = .phoneEnroll
    case "TOTP Enroll":
      self = .totpEnroll
    case "Multifactor unenroll":
      self = .multifactorUnenroll
    default:
      return nil
    }
  }
}

  // MARK: DataSourceProvidable

class MultiFactorMenuData : AuthMenuData {
  
  static var multifactorSection: Section {
    let header = "Multi Factor"
    let items: [Item] = [
      Item(title: MultiFactorMenu.phoneEnroll.name),
      Item(title: MultiFactorMenu.totpEnroll.name),
      Item(title: MultiFactorMenu.multifactorUnenroll.name),
    ]
    return Section(headerDescription: header, items: items)
  }
  
  
}
  
//  static var sections: [Section] =
//  [multifactorSection]
  
//  static var authLinkSections: [Section] {
//    let allItems = AuthMenuData.sections.flatMap { $0.items }
//    let header = "Manage linking between providers"
//    let footer =
//    "Select an unchecked row to link the currently signed in user to that auth provider. To unlink the user from a linked provider, select its corresponding row marked with a checkmark."
//    return [Section(headerDescription: header, footerDescription: footer, items: allItems)]
//  }
  
//  var sections: [Section] = AuthMenuData.sections
