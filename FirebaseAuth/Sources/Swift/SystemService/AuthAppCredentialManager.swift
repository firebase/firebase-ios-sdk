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

#if !os(macOS)
  import Foundation

  /// A class to manage app credentials backed by iOS Keychain.
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  class AuthAppCredentialManager: NSObject {
    let kKeychainDataKey = "app_credentials"
    let kFullCredentialKey = "full_credential"
    let kPendingReceiptsKey = "pending_receipts"

    /// The full credential (which has a secret) to be used by the app, if one is available.

    var credential: AuthAppCredential?

    /// The maximum (but not necessarily the minimum) number of pending receipts to be kept.
    ///
    /// Only tests should access this property.
    let maximumNumberOfPendingReceipts = 32

    init(withKeychain keychain: AuthKeychainServices) {
      keychainServices = keychain
      if let encodedData = try? keychain.data(forKey: kKeychainDataKey),
         let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: encodedData) {
        if let credential = unarchiver.decodeObject(of: AuthAppCredential.self,
                                                    forKey: kFullCredentialKey) {
          self.credential = credential
        }
        if let pendingReceipts = unarchiver.decodeObject(
          of: [NSString.self, NSArray.self],
          forKey: kPendingReceiptsKey
        ) as? [String] {
          self.pendingReceipts = pendingReceipts
        }
      }
    }

    func didStartVerificationInternal(withReceipt receipt: String,
                                      timeout: TimeInterval,
                                      callback: @escaping (AuthAppCredential) -> Void) {
      pendingReceipts = pendingReceipts.filter { $0 != receipt }
      if pendingReceipts.count >= maximumNumberOfPendingReceipts {
        pendingReceipts.remove(at: 0)
      }
      pendingReceipts.append(receipt)
      callbacksByReceipt[receipt] = callback
      saveData()
      kAuthGlobalWorkQueue.asyncAfter(deadline: .now() + timeout) {
        self.callbackWithReceipt(receipt)
      }
    }

    func didStartVerification(withReceipt receipt: String,
                              timeout: TimeInterval) async -> AuthAppCredential {
      return await withCheckedContinuation { continuation in
        self.didStartVerificationInternal(withReceipt: receipt, timeout: timeout) { credential in
          continuation.resume(returning: credential)
        }
      }
    }

    func canFinishVerification(withReceipt receipt: String, secret: String) -> Bool {
      guard pendingReceipts.contains(receipt) else {
        return false
      }
      pendingReceipts = pendingReceipts.filter { $0 != receipt }
      credential = AuthAppCredential(receipt: receipt, secret: secret)
      saveData()
      callbackWithReceipt(receipt)
      return true
    }

    func clearCredential() {
      credential = nil
      saveData()
    }

    // MARK: Internal methods

    private func saveData() {
      let archiver = NSKeyedArchiver(requiringSecureCoding: true)
      archiver.encode(credential, forKey: kFullCredentialKey)
      archiver.encode(pendingReceipts, forKey: kPendingReceiptsKey)
      archiver.finishEncoding()
      try? keychainServices.setData(archiver.encodedData, forKey: kKeychainDataKey)
    }

    private func callbackWithReceipt(_ receipt: String) {
      guard let callback = callbacksByReceipt[receipt] else {
        return
      }
      callbacksByReceipt.removeValue(forKey: receipt)
      if let fakeCredential {
        callback(fakeCredential)
      } else if let credential {
        callback(credential)
      } else {
        callback(AuthAppCredential(receipt: receipt, secret: nil))
      }
    }

    /// The keychain for app credentials to load from and to save to.
    private let keychainServices: AuthKeychainServices

    /// A list of pending receipts sorted in the order they were recorded.
    private var pendingReceipts: [String] = []

    /// A map from pending receipts to callbacks.
    private var callbacksByReceipt: [String: (AuthAppCredential) -> Void] = [:]

    // Only for testing.
    var fakeCredential: AuthAppCredential?
  }
#endif
