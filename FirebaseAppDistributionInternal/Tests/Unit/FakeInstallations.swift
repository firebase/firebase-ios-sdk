//
//  FakeInstallations.swift
//  FirebaseAppDistributionInternal-Unit-unit
//
//  Created by Tejas Deshpande on 3/2/23.
//

import Foundation
@testable import FirebaseInstallations
@testable import FirebaseAppDistributionInternal

class FakeInstallations: InstallationsProtocol {
  func authToken(completion: @escaping (InstallationsAuthTokenResult?, Error?) -> Void) {
    let authToken = InstallationsAuthTokenResult(token: "abcde", expirationDate: Date())
    completion(authToken, nil)
  }

  func installationID(completion: @escaping (String?, Error?) -> Void) {
    let installationID = "abcde"

    completion(installationID, nil)
  }
  
  static func installations() -> InstallationsProtocol {
    return FakeInstallations()
  }
}
