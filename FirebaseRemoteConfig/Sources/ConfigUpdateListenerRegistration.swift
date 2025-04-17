import Foundation

// Typealias for the config update listener closure, mirroring FIRRemoteConfigUpdateCompletion
// We define it here or in a common place, assuming it might be used elsewhere.
// If FIRRemoteConfigUpdateCompletion is already translated elsewhere, adjust accordingly.
typealias ConfigUpdateCompletion = (_ configUpdate: RemoteConfigUpdate?, _ error: Error?) -> Void

/// Listener registration returned by `addOnConfigUpdateListener`. Calling its method `remove` stops
/// the associated listener from receiving config updates and unregisters itself.
@objc(FIRConfigUpdateListenerRegistration)
public class ConfigUpdateListenerRegistration: NSObject {
  // Keep a reference to the Realtime client (needs to be updated if RCNConfigRealtime is translated)
  // For now, use AnyObject until RCNConfigRealtime is translated.
  // Make it weak to avoid potential retain cycles if the Realtime client holds registrations strongly.
  private weak var realtimeClient: AnyObject? // TODO: Update type to translated RCNConfigRealtime/equivalent
  private let listener: ConfigUpdateCompletion

  // Internal initializer
  // The client parameter type needs to be updated once RCNConfigRealtime is translated.
  init(client: AnyObject, listener: @escaping ConfigUpdateCompletion) {
    self.realtimeClient = client
    self.listener = listener
    super.init()
  }

  /// Default initializer is unavailable.
  override private init() {
    fatalError("Default initializer is not available.")
  }

  /// Removes the listener associated with this registration. After the
  /// initial call, subsequent calls have no effect.
  @objc public func remove() {
    // Call the remove method on the realtime client.
    // This assumes the translated RCNConfigRealtime will have a similar method.
    // The exact method signature might change after translation.
    // Using performSelector as a placeholder for dynamic dispatch until types are resolved.
    _ = realtimeClient?.perform(#selector(removeConfigUpdateListener(_:)), with: listener)

    // Nil out the client reference after removing to potentially break cycles sooner?
    // Or rely on the weak reference. Let's keep it simple for now.
    // self.realtimeClient = nil
  }

  // Placeholder selector for the removeConfigUpdateListener method.
  // This allows the perform(#selector(...)) call to compile.
  // The actual implementation will be in the translated RCNConfigRealtime class.
  @objc private func removeConfigUpdateListener(_ listener: Any) {
      // This is a stub implementation within the registration object itself
      // and should not actually be called. The call should go to the realtimeClient.
      print("Error: removeConfigUpdateListener called on registration object instead of client.")
  }
}
