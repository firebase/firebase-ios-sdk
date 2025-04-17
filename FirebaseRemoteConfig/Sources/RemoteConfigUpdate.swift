import Foundation

/// Represents the config update reported by the Remote Config real-time service.
/// An instance of this class is passed to the config update listener when a new config
/// version has been fetched from the backend.
@objc(FIRRemoteConfigUpdate)
public class RemoteConfigUpdate: NSObject {
  /// Set of parameter keys whose values have been updated from the currently activated values.
  /// This includes keys that are added, deleted, and whose value, value source, or metadata has changed.
  @objc public let updatedKeys: Set<String>

  /// Internal initializer.
  /// - Parameter updatedKeys: The set of keys that have been updated.
  internal init(updatedKeys: Set<String>) {
    self.updatedKeys = updatedKeys
    super.init()
  }

  /// Default initializer is unavailable.
  override private init() {
    fatalError("Default initializer is not available.")
  }
}
