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

#if !os(watchOS)
import Foundation
import GameKit

/**
   @brief A concrete implementation of `AuthProvider` for Game Center Sign In. Not available on watchOS.
*/

@objc(FIRGameCenterAuthProvider) open class GameCenterAuthProvider: NSObject {

  @objc static public let id = "gc.apple.com"

  /** @fn
      @brief Creates an `AuthCredential` for a Game Center sign in.
   */
  open class func getCredential(completion: @escaping (AuthCredential?, Error?) -> Void) {
    // TODO:  Linking GameKit.framework without using it on macOS results in App Store rejection.
    let localPlayer = GKLocalPlayer.local
    if !localPlayer.isAuthenticated {
      // TODO: pass right error
      completion(nil, nil)
      return
    }
    localPlayer.generateIdentityVerificationSignature() { publicKeyURL, signature, salt, timestamp, error in
      if error != nil {
        completion(nil, error)
      } else {
        /**
         @c `localPlayer.alias` is actually the displayname needed, instead of
         `localPlayer.displayname`. For more information, check
         https://developer.apple.com/documentation/gamekit/gkplayer
         **/
        let displayName = localPlayer.alias
        let credential = GameCenterAuthCredential(withPlayerID: localPlayer.playerID,
                                                  publicKeyURL: publicKeyURL,
                                                  signature: signature,
                                                  salt: salt,
                                                  timestamp: timestamp,
                                                  displayName: displayName)
        completion(credential, nil)
      }
    }
  }

  /** @fn
      @brief Creates an `AuthCredential` for a Game Center sign in.
   */
  @available(iOS 13, tvOS 13, macOS 10.15, watchOS 8, *)
  open class func getCredential() async throws -> AuthCredential {
    return try await withCheckedThrowingContinuation { continuation in
      getCredential() { credential, error in
        if let credential = credential {
          continuation.resume(returning: credential)
        } else {
          continuation.resume(throwing: error!) // TODO: Change to ?? and generate unknown error
        }
      }
    }
  }
}

// Change to internal
@objc(FIRGameCenterAuthCredential) public class GameCenterAuthCredential: AuthCredential, NSSecureCoding {
  @objc public let playerID: String
  @objc public let publicKeyURL: URL?
  @objc public let signature: Data?
  @objc public let salt: Data?
  @objc public let timestamp: UInt64
  @objc public let displayName: String

  /**
      @brief Designated initializer.
      @param playerID The ID of the Game Center local player.
      @param publicKeyURL The URL for the public encryption key.
      @param signature The verification signature generated.
      @param salt A random string used to compute the hash and keep it randomized.
      @param timestamp The date and time that the signature was created.
      @param displayName The display name of the Game Center player.
   */
  init(withPlayerID playerID:String, publicKeyURL: URL?, signature: Data?, salt: Data?,
       timestamp: UInt64, displayName: String) {

    self.playerID = playerID
    self.publicKeyURL = publicKeyURL
    self.signature = signature
    self.salt = salt
    self.timestamp = timestamp
    self.displayName = displayName
    super.init(provider: GameCenterAuthProvider.id)
  }

  public static var supportsSecureCoding = true

  public func encode(with coder: NSCoder) {
    coder.encode("playerID")
    coder.encode("publicKeyURL")
    coder.encode("signature")
    coder.encode("salt")
    coder.encode("timestamp")
    coder.encode("displayName")
  }

  public required init?(coder: NSCoder) {
    guard let playerID = coder.decodeObject(forKey: "playerID") as? String,
          let timestamp = coder.decodeObject(forKey: "timestamp") as? UInt64,
          let displayName = coder.decodeObject(forKey: "displayName") as? String else {
      return nil
    }
    self.playerID = playerID
    self.timestamp = timestamp
    self.displayName = displayName
    self.publicKeyURL = coder.decodeObject(forKey: "publicKeyURL") as? URL
    self.signature = coder.decodeObject(forKey: "signature") as? Data
    self.salt = coder.decodeObject(forKey: "salt") as? Data
    super.init(provider: GameCenterAuthProvider.id)
  }
}
#endif
