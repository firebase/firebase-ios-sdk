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

/// The utility class to manage data storage in NSUserDefaults.
class AuthUserDefaults {
  /// The name of the persistent domain in user defaults.

  private let persistentDomainName: String

  /// The backing NSUserDefaults storage for this instance.

  private let storage: UserDefaults

  static func storage(identifier: String) -> Self {
    return Self(service: identifier)
  }

  required init(service: String) {
    persistentDomainName = kPersistentDomainNamePrefix + service
    storage = UserDefaults()
  }

  func data(forKey key: String) -> Data? {
    guard let allData = storage.persistentDomain(forName: persistentDomainName)
    else { return nil }
    if let data = allData[key] as? Data {
      return data
    }
    return nil
  }

  func setData(_ data: Data, forKey key: String) {
    var allData = storage.persistentDomain(forName: persistentDomainName) ?? [:]
    allData[key] = data
    storage.setPersistentDomain(allData, forName: persistentDomainName)
  }

  func removeData(forKey key: String) {
    guard var allData = storage.persistentDomain(forName: persistentDomainName) else { return }
    allData.removeValue(forKey: key)
    storage.setPersistentDomain(allData, forName: persistentDomainName)
  }

  /// Clears all data from the storage.
  ///
  /// This method is only supposed to be called from tests.
  func clear() {
    storage.setPersistentDomain([:], forName: persistentDomainName)
  }
}
