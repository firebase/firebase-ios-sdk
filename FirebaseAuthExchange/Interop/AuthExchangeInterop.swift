/// The name of the `NSNotificationCenter` notification that is posted when the Auth Exchange
/// token changes. The object parameter of the notification is the new token.
@objc(FIRAuthExchangeInternalTokenDidChangeNotification)
public static let AuthExchangeInternalTokenDidChange: NSNotification.Name

/// The type of the listener handle returned by `addAuthExchangeInternalTokenListener`.
@objc(FIRAuthExchangeInternalTokenListenerHandle) typealias AuthExchangeInternalTokenListenerHandle = NSObjectProtocol


/// Firebase Auth Exchange SDK interop protocol. This is intended for use only by other Firebase
/// SDKs.
@objc(FIRAuthExchangeInterop) public protocol AuthExchangeInterop {

  /// Returns the current Auth Exchange token if valid and fetches a new one from the backend
  /// otherwise. If `forceRefresh` is true, then a new token is fetched regardless of the
  /// validity of the stored token.
  ///
  /// This method is an interop method and intended for use only by other Firebase SDKs.
  public func getToken(forceRefresh: Bool) async throws -> String

  /// See `getToken(forceRefresh:)`.
  @objc(getTokenForcingRefresh:completion:)
  public func getToken(forceRefresh: Bool, completion: ((String?, Error?) -> Void))


  // Listener methods

  /// Registers a block that listens to changes in the Auth Exchange token.
  @objc
  public func addAuthExchangeInternalTokenListener(_ listener: String -> Void)
                                                     -> AuthExchangeInternalTokenListenerHandle

  // Unregisters a block from listening to changes in the Auth Exchange token.
  @objc public func removeAuthExchangeInternalTokenListener(
      _ listenerHandle: AuthExchangeInternalTokenListenerHandle)
}

