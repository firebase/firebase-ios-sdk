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

/** @class FIRActionCodeURL
    @brief This class will allow developers to easily extract information about out of band links.
 */
@objc(FIRActionCodeURL) public class ActionCodeURL: NSObject {
  /** @property APIKey
      @brief Returns the API key from the link. nil, if not provided.
   */
  @objc public let apiKey: String?

  /** @property operation
      @brief Returns the mode of oob action. The property will be of `FIRActionCodeOperation` type.
          It will return `FIRActionCodeOperationUnknown` if no oob action is provided.
   */
  @objc public let operation: ActionCodeOperation

  /** @property code
      @brief Returns the email action code from the link. nil, if not provided.
   */
  @objc public let code: String?

  /** @property continueURL
      @brief Returns the continue URL from the link. nil, if not provided.
   */
  @objc public let continueURL: URL?

  /** @property languageCode
      @brief Returns the language code from the link. nil, if not provided.
   */
  @objc public let languageCode: String?

  /** @fn actionCodeURLWithLink:
      @brief Construct an `ActionCodeURL` from an out of band link (e.g. email link).
      @param link The oob link string used to construct the action code URL.
      @return The `ActionCodeURL` object constructed based on the oob link provided.
   */
  @objc(actionCodeURLWithLink:) public init?(link: String) {
    var queryItems = ActionCodeURL.parseURL(link)
    if queryItems.count == 0 {
      let urlComponents = URLComponents(string: link)
      if let query = urlComponents?.query {
        queryItems = ActionCodeURL.parseURL(query)
      }
    }
    guard queryItems.count > 0 else {
      return nil
    }
    apiKey = queryItems["apiKey"]
    operation = ActionCodeInfo.actionCodeOperation(forRequestType: queryItems["mode"])
    code = queryItems["oobCode"]
    if let continueURL = queryItems["continueUrl"] {
      self.continueURL = URL(string: continueURL)
    } else {
      continueURL = nil
    }
    languageCode = queryItems["languageCode"]
  }

  // TODO: internal below here.

  @objc public class func parseURL(_ urlString: String) -> [String: String] {
    guard let linkURL = URLComponents(string: urlString)?.query else {
      return [:]
    }
    var queryItems: [String: String] = [:]
    let urlComponents = linkURL.components(separatedBy: "&")
    for component in urlComponents {
      let splitArray = component.split(separator: "=")
      if let queryItemKey = String(splitArray[0]).removingPercentEncoding,
         let queryItemValue = String(splitArray[1]).removingPercentEncoding {
        queryItems[queryItemKey] = queryItemValue
      }
    }
    return queryItems
  }
}
