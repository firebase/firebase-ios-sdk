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

@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
extension UserMetadata: NSSecureCoding {}

/// A data class representing the metadata corresponding to a Firebase user.
@available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
@objc(FIRUserMetadata) open class UserMetadata: NSObject {
  /// Stores the last sign in date for the corresponding Firebase user.
  @objc public let lastSignInDate: Date?

  /// Stores the creation date for the corresponding Firebase user.
  @objc public let creationDate: Date?

  init(withCreationDate creationDate: Date?, lastSignInDate: Date?) {
    self.creationDate = creationDate
    self.lastSignInDate = lastSignInDate
  }

  // MARK: Secure Coding

  private static let kCreationDateCodingKey = "creationDate"
  private static let kLastSignInDateCodingKey = "lastSignInDate"

  public static var supportsSecureCoding: Bool {
    return true
  }

  public func encode(with coder: NSCoder) {
    coder.encode(creationDate, forKey: UserMetadata.kCreationDateCodingKey)
    coder.encode(lastSignInDate, forKey: UserMetadata.kLastSignInDateCodingKey)
  }

  public required convenience init?(coder: NSCoder) {
    let creationDate = coder.decodeObject(of: [NSDate.self],
                                          forKey: UserMetadata.kCreationDateCodingKey)
    let lastSignInDate = coder.decodeObject(of: [NSDate.self],
                                            forKey: UserMetadata.kLastSignInDateCodingKey)
    self.init(withCreationDate: creationDate as? Date, lastSignInDate: lastSignInDate as? Date)
  }
}
