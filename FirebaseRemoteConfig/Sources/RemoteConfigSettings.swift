import Foundation

/// Firebase Remote Config settings.
@objc(FIRRemoteConfigSettings)
public class RemoteConfigSettings: NSObject {
  /// Indicates the default value in seconds to set for the minimum interval that needs to elapse
  /// before a fetch request can again be made to the Remote Config backend. After a fetch request to
  /// the backend has succeeded, no additional fetch requests to the backend will be allowed until the
  /// minimum fetch interval expires. Note that you can override this default on a per-fetch request
  /// basis using `RemoteConfig.fetch(withExpirationDuration:)`. For example, setting
  /// the expiration duration to 0 in the fetch request will override the `minimumFetchInterval` and
  /// allow the request to proceed.
  ///
  /// The default interval is 12 hours.
  @objc public var minimumFetchInterval: TimeInterval

  /// Indicates the default value in seconds to abandon a pending fetch request made to the backend.
  /// This value is set for outgoing requests as the `timeoutIntervalForRequest` as well as the
  /// `timeoutIntervalForResource` on the `URLSession`'s configuration.
  ///
  /// The default timeout is 60 seconds.
  @objc public var fetchTimeout: TimeInterval

  /// Initializes FIRRemoteConfigSettings with default values.
  @objc
  public override init() {
    // Default values match the ones set in RCNConfigSettings init and FIRRemoteConfig setDefaultConfigSettings
    minimumFetchInterval = 43200.0 // 12 hours * 60 minutes * 60 seconds
    fetchTimeout = 60.0
    super.init()
  }
}
