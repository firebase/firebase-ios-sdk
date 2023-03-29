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

private let kPersistentDomainNamePrefix = "com.google.Firebase.Auth."

// TODO: Remove this type after all tests and internal call sites are converted to Swift
// This is added since a throwing function returning Optional values in Swift cannot be
// exposed to Objective-C due to convention and meaning of nil values in Objective-C.
// This wrapper allows us to always return a value, thus allowing us to expose Objective-C api.
@objc(FIRDataWrapper) public class DataWrapper: NSObject {
  @objc public let data: Data?
  @objc public init(data: Data?) {
    self.data = data
  }
}

/** @class FIRAuthUserDefaults
    @brief The utility class to storage data in NSUserDefaults.
 */
@objc(FIRAuthUserDefaults) public class AuthUserDefaults: NSObject, AuthStorage {
  /** @var _persistentDomainName
      @brief The name of the persistent domain in user defaults.
   */
  private let persistentDomainName: String

  /** @var _storage
      @brief The backing NSUserDefaults storage for this instance.
   */
  private let storage: UserDefaults

  @objc public static func storage(identifier: String) -> Self {
    return Self(service: identifier)
  }

  @objc public required init(service: String) {
    persistentDomainName = kPersistentDomainNamePrefix + service
    storage = UserDefaults()
  }

  @objc public func data(forKey key: String) throws -> DataWrapper {
    guard let allData = storage.persistentDomain(forName: persistentDomainName)
    else { return DataWrapper(data: nil) }
    if let data = allData[key] as? Data {
      return DataWrapper(data: data)
    }

    return DataWrapper(data: nil)
  }

  @objc public func setData(_ data: Data, forKey key: String) throws {
    var allData = storage.persistentDomain(forName: persistentDomainName) ?? [:]
    allData[key] = data
    storage.setPersistentDomain(allData, forName: persistentDomainName)
  }

  @objc public func removeData(forKey key: String) throws {
    guard var allData = storage.persistentDomain(forName: persistentDomainName) else { return }
    allData.removeValue(forKey: key)
    storage.setPersistentDomain(allData, forName: persistentDomainName)
  }

  /** @fn clear
      @brief Clears all data from the storage.
      @remarks This method is only supposed to be called from tests.
   */
  @objc public func clear() {
    storage.setPersistentDomain([:], forName: persistentDomainName)
  }
}
