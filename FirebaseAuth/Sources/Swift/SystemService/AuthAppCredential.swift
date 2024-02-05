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

/// A class represents a credential that proves the identity of the app.
@objc(FIRAuthAppCredential) class AuthAppCredential: NSObject, NSSecureCoding {
  /// The server acknowledgement of receiving client's claim of identity.
  var receipt: String

  /// The secret that the client received from server via a trusted channel, if ever.
  var secret: String?

  /// Initializes the instance.
  /// - Parameter receipt: The server acknowledgement of receiving client's claim of identity.
  /// - Parameter secret: The secret that the client received from server via a trusted channel, if
  /// ever.
  /// - Returns: The initialized instance.
  init(receipt: String, secret: String?) {
    self.secret = secret
    self.receipt = receipt
  }

  // MARK: NSSecureCoding

  private static let kReceiptKey = "receipt"
  private static let kSecretKey = "secret"

  static var supportsSecureCoding: Bool {
    true
  }

  required convenience init?(coder: NSCoder) {
    guard let receipt = coder.decodeObject(of: NSString.self,
                                           forKey: AuthAppCredential.kReceiptKey) as? String
    else {
      return nil
    }
    let secret = coder.decodeObject(of: NSString.self,
                                    forKey: AuthAppCredential.kSecretKey) as? String
    self.init(receipt: receipt, secret: secret)
  }

  func encode(with coder: NSCoder) {
    coder.encode(receipt, forKey: AuthAppCredential.kReceiptKey)
    coder.encode(secret, forKey: AuthAppCredential.kSecretKey)
  }
}
