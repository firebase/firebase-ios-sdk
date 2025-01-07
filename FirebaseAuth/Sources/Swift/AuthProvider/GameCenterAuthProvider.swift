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

  // TODO: Delete this when minimum iOS version passes 13.5.
  /// WarningWorkaround is needed because playerID is deprecated in iOS 13.0 but still needed until
  /// 13.5 when the fetchItems API was introduced.
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  private protocol WarningWorkaround {
    static func pre135Credential(localPlayer: GKLocalPlayer,
                                 completion: @escaping (AuthCredential?, Error?) -> Void)
  }

  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  extension GameCenterAuthProvider: WarningWorkaround {}

  /// A concrete implementation of `AuthProvider` for Game Center Sign In. Not available on watchOS.
  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  @objc(FIRGameCenterAuthProvider) open class GameCenterAuthProvider: NSObject {
    /// A string constant identifying the Game Center identity provider.
    @objc public static let id = "gc.apple.com"

    /// Creates an `AuthCredential` for a Game Center sign in.
    @objc open class func getCredential(completion: @escaping (AuthCredential?, Error?) -> Void) {
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
            let credential = GameCenterAuthCredential(withPlayerID: "",
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
        (GameCenterAuthProvider.self as WarningWorkaround.Type).pre135Credential(
          localPlayer: localPlayer, completion: completion
        )
      }
    }

    @available(iOS, deprecated: 13.0)
    @available(tvOS, deprecated: 13.0)
    @available(macOS, deprecated: 10.15.0)
    @available(macCatalyst, deprecated: 13.0)
    fileprivate class func pre135Credential(localPlayer: GKLocalPlayer,
                                            completion: @escaping (AuthCredential?, Error?)
                                              -> Void) {
      localPlayer
        .generateIdentityVerificationSignature { publicKeyURL, signature, salt, timestamp, error in
          if error != nil {
            completion(nil, error)
          } else {
            /**
             `localPlayer.alias` is actually the displayname needed, instead of
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

    /// Creates an `AuthCredential` for a Game Center sign in.
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

    @available(*, unavailable)
    @objc override public init() {
      fatalError("This class is not meant to be initialized.")
    }
  }

  @available(iOS 13, tvOS 13, macOS 10.15, macCatalyst 13, watchOS 7, *)
  @objc(FIRGameCenterAuthCredential)
  class GameCenterAuthCredential: AuthCredential, NSSecureCoding, @unchecked Sendable {
    let playerID: String?
    let teamPlayerID: String?
    let gamePlayerID: String?
    let publicKeyURL: URL?
    let signature: Data?
    let salt: Data?
    let timestamp: UInt64?
    let displayName: String?

    /// - Parameter playerID: The ID of the Game Center local player.
    /// - Parameter teamPlayerID: The teamPlayerID of the Game Center local player.
    /// - Parameter gamePlayerID: The gamePlayerID of the Game Center local player.
    /// - Parameter publicKeyURL: The URL for the public encryption key.
    /// - Parameter signature: The verification signature generated.
    /// - Parameter salt: A random string used to compute the hash and keep it randomized.
    /// - Parameter timestamp: The date and time that the signature was created.
    /// - Parameter displayName: The display name of the Game Center player.
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

    // MARK: Secure Coding

    static let supportsSecureCoding = true

    func encode(with coder: NSCoder) {
      coder.encode(playerID, forKey: "playerID")
      coder.encode(teamPlayerID, forKey: "teamPlayerID")
      coder.encode(gamePlayerID, forKey: "gamePlayerID")
      coder.encode(publicKeyURL, forKey: "publicKeyURL")
      coder.encode(signature, forKey: "signature")
      coder.encode(salt, forKey: "salt")
      coder.encode(timestamp, forKey: "timestamp")
      coder.encode(displayName, forKey: "displayName")
    }

    required init?(coder: NSCoder) {
      playerID = coder.decodeObject(of: NSString.self, forKey: "playerID") as String?
      teamPlayerID = coder.decodeObject(
        of: NSString.self,
        forKey: "teamPlayerID"
      ) as String?
      gamePlayerID = coder.decodeObject(
        of: NSString.self,
        forKey: "gamePlayerID"
      ) as String?
      timestamp = coder.decodeObject(of: NSNumber.self, forKey: "timestamp") as? UInt64
      displayName = coder.decodeObject(
        of: NSString.self,
        forKey: "displayName"
      ) as String?
      publicKeyURL = coder.decodeObject(forKey: "publicKeyURL") as? URL
      signature = coder.decodeObject(of: NSData.self, forKey: "signature") as? Data
      salt = coder.decodeObject(of: NSData.self, forKey: "salt") as? Data
      super.init(provider: GameCenterAuthProvider.id)
    }
  }
#endif
