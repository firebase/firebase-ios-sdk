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
    @objc public static let id = "gc.apple.com"

    /** @fn
        @brief Creates an `AuthCredential` for a Game Center sign in.
     */
    open class func getCredential(completion: @escaping (AuthCredential?, Error?) -> Void) {
      /**
       Linking GameKit.framework without using it on macOS results in App Store rejection.
       Thus we don't link GameKit.framework to our SDK directly. `optionalLocalPlayer` is used for
       checking whether the APP that consuming our SDK has linked GameKit.framework. If not, a
       `GameKitNotLinkedError` will be raised.
       **/
      guard let _: AnyClass = NSClassFromString("GKLocalPlayer") else {
        completion(nil, AuthErrorUtils.gameKitNotLinkedError())
        return
      }

      let localPlayer = GKLocalPlayer.local
      guard localPlayer.isAuthenticated else {
        completion(nil, AuthErrorUtils.localPlayerNotAuthenticatedError())
        return
      }

      if #available(iOS 13.5, macOS 10.15.5, macCatalyst 13.5, tvOS 13.4.8, *) {
        localPlayer.fetchItems { publicKeyURL, signature, salt, timestamp, error in
          if let error = error {
            completion(nil, error)
          } else {
            let credential = GameCenterAuthCredential(withPlayerID: localPlayer.playerID,
                                                      teamPlayerID: localPlayer.teamPlayerID,
                                                      gamePlayerID: localPlayer.gamePlayerID,
                                                      publicKeyURL: publicKeyURL,
                                                      signature: signature,
                                                      salt: salt,
                                                      timestamp: timestamp,
                                                      displayName: localPlayer.displayName)
            completion(credential, nil)
          }
        }
      } else {
        localPlayer
          .generateIdentityVerificationSignature { publicKeyURL, signature, salt, timestamp, error in
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
                                                        teamPlayerID: nil,
                                                        gamePlayerID: nil,
                                                        publicKeyURL: publicKeyURL,
                                                        signature: signature,
                                                        salt: salt,
                                                        timestamp: timestamp,
                                                        displayName: displayName)
              completion(credential, nil)
            }
          }
      }
    }

    /** @fn
        @brief Creates an `AuthCredential` for a Game Center sign in.
     */
    @available(iOS 13, tvOS 13, macOS 10.15, watchOS 8, *)
    open class func getCredential() async throws -> AuthCredential {
      return try await withCheckedThrowingContinuation { continuation in
        getCredential { credential, error in
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
  @objc(FIRGameCenterAuthCredential) public class GameCenterAuthCredential: AuthCredential,
    NSSecureCoding {
    @objc public let playerID: String
    @objc public let teamPlayerID: String?
    @objc public let gamePlayerID: String?
    @objc public let publicKeyURL: URL?
    @objc public let signature: Data?
    @objc public let salt: Data?
    @objc public let timestamp: UInt64
    @objc public let displayName: String

    /**
        @brief Designated initializer.
        @param playerID The ID of the Game Center local player.
        @param teamPlayerID The teamPlayerID of the Game Center local player.
        @param gamePlayerID The gamePlayerID of the Game Center local player.
        @param publicKeyURL The URL for the public encryption key.
        @param signature The verification signature generated.
        @param salt A random string used to compute the hash and keep it randomized.
        @param timestamp The date and time that the signature was created.
        @param displayName The display name of the Game Center player.
     */
    init(withPlayerID playerID: String, teamPlayerID: String?, gamePlayerID: String?,
         publicKeyURL: URL?, signature: Data?, salt: Data?,
         timestamp: UInt64, displayName: String) {
      self.playerID = playerID
      self.teamPlayerID = teamPlayerID
      self.gamePlayerID = gamePlayerID
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
      coder.encode("teamPlayerID")
      coder.encode("gamePlayerID")
      coder.encode("publicKeyURL")
      coder.encode("signature")
      coder.encode("salt")
      coder.encode("timestamp")
      coder.encode("displayName")
    }

    public required init?(coder: NSCoder) {
      guard let playerID = coder.decodeObject(forKey: "playerID") as? String,
            let teamPlayerID = coder.decodeObject(forKey: "teamPlayerID") as? String,
            let gamePlayerID = coder.decodeObject(forKey: "gamePlayerID") as? String,
            let timestamp = coder.decodeObject(forKey: "timestamp") as? UInt64,
            let displayName = coder.decodeObject(forKey: "displayName") as? String else {
        return nil
      }
      self.playerID = playerID
      self.teamPlayerID = teamPlayerID
      self.gamePlayerID = gamePlayerID
      self.timestamp = timestamp
      self.displayName = displayName
      publicKeyURL = coder.decodeObject(forKey: "publicKeyURL") as? URL
      signature = coder.decodeObject(forKey: "signature") as? Data
      salt = coder.decodeObject(forKey: "salt") as? Data
      super.init(provider: GameCenterAuthProvider.id)
    }
  }
#endif
