import FirebaseAppCheck
import FirebaseCore
import Foundation

/// An `AppCheckProviderFactory` for the Test App.
///
/// Defaults to the `AppCheckDebugProvider` unless the `FirebaseApp` `name` contains
/// ``notConfiguredName``, in which case App Check is not configured; this facilitates integration
/// testing of App Check failure cases.
public class TestAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
  /// The name, or a substring of the name, of Firebase apps where App Check is not configured.
  public static let notConfiguredName = "app-check-not-configured"

  /// Returns the `AppCheckDebugProvider` unless  `app.name` contains ``notConfiguredName``.
  public func createProvider(with app: FirebaseApp) -> (any AppCheckProvider)? {
    if app.name.contains(TestAppCheckProviderFactory.notConfiguredName) {
      return nil
    }

    return AppCheckDebugProvider(app: app)
  }
}
