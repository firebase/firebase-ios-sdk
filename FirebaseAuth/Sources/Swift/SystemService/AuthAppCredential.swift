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

/** @var kReceiptKey
    @brief The key used to encode the receipt property for NSSecureCoding.
 */
private let kReceiptKey = "receipt"

/** @var kSecretKey
    @brief The key used to encode the secret property for NSSecureCoding.
 */
private let kSecretKey = "secret"

// TODO: Remove objc public after Sample app is replaced.

/** @class FIRAuthAppCredential
    @brief A class represents a credential that proves the identity of the app.
 */
@objc(FIRAuthAppCredential) public class AuthAppCredential: NSObject, NSSecureCoding {
  /** @property receipt
      @brief The server acknowledgement of receiving client's claim of identity.
   */
  @objc public var receipt: String

  /** @property secret
      @brief The secret that the client received from server via a trusted channel, if ever.
   */
  @objc public var secret: String?

  /** @fn initWithReceipt:secret:
      @brief Initializes the instance.
      @param receipt The server acknowledgement of receiving client's claim of identity.
      @param secret The secret that the client received from server via a trusted channel, if ever.
      @return The initialized instance.
   */
  @objc public init(receipt: String, secret: String?) {
    self.secret = secret
    self.receipt = receipt
  }

  // MARK: NSSecureCoding

  public static var supportsSecureCoding: Bool {
    true
  }

  public required convenience init?(coder: NSCoder) {
    guard let receipt = coder.decodeObject(of: [NSString.self], forKey: kReceiptKey) as? String
    else {
      return nil
    }
    let secret = coder.decodeObject(of: [NSString.self], forKey: kSecretKey) as? String
    self.init(receipt: receipt, secret: secret)
  }

  public func encode(with coder: NSCoder) {
    coder.encode(receipt, forKey: kReceiptKey)
    coder.encode(secret, forKey: kSecretKey)
  }
}
