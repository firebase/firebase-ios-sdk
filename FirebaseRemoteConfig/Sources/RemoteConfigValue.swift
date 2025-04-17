import Foundation

/// This enum indicates the source of fetched Remote Config data.
/// - Note: This mirrors the Objective-C enum `FIRRemoteConfigSource`.
@objc(FIRRemoteConfigSource) public enum RemoteConfigSource: Int {
  /// The data source is the Remote Config backend.
  case remote = 0
  /// The data source is the default config defined for this app.
  case defaultValue = 1
  /// The data doesn't exist, returns a static initialized value.
  case staticValue = 2
}

/// This class provides a wrapper for Remote Config parameter values, with methods to get parameter
/// values as different data types.
@objc(FIRRemoteConfigValue)
public class RemoteConfigValue: NSObject, NSCopying {
  /// Underlying data for the config value.
  private let valueData: Data
  /// Identifies the source of the fetched value.
  @objc public let source: RemoteConfigSource

  /// Designated initializer.
  /// - Parameters:
  ///   - data: The data representation of the value.
  ///   - source: The source of the config value.
  @objc
  public init(data: Data, source: RemoteConfigSource) {
    self.valueData = data
    self.source = source
    super.init()
  }

  /// Convenience initializer for static values (empty data).
  override convenience init() {
    self.init(data: Data(), source: .staticValue)
  }

  /// Gets the value as a string. Returns an empty string if the data cannot be UTF-8 decoded.
  @objc public var stringValue: String {
    return String(data: valueData, encoding: .utf8) ?? ""
  }

  /// Gets the value as an `NSNumber`. Tries to interpret the string value as a double.
  @objc public var numberValue: NSNumber {
    // Mimics Objective-C behavior: NSString.doubleValue returns 0.0 if conversion fails.
    return NSNumber(value: Double(stringValue) ?? 0.0)
  }

  /// Gets the value as a `Data` object.
  @objc public var dataValue: Data {
    return valueData
  }

  /// Gets the value as a boolean. Tries to interpret the string value as a boolean.
  @objc public var boolValue: Bool {
    // Mimics Objective-C behavior: NSString.boolValue checks for specific prefixes/values.
    let lowercasedString = stringValue.lowercased()
    return lowercasedString == "true" || lowercasedString == "yes" || lowercasedString == "on" ||
           lowercasedString == "1" || (Double(stringValue) != 0.0 && lowercasedString != "false" && lowercasedString != "no" && lowercasedString != "off")

  }

  /// Gets a Foundation object (`NSDictionary` / `NSArray`) by parsing the value as JSON.
  /// Returns `nil` if the data is not valid JSON.
  @objc public var jsonValue: Any? {
    guard !valueData.isEmpty else { return nil }
    do {
      // Mimics Objective-C behavior using kNilOptions
      return try JSONSerialization.jsonObject(with: valueData, options: [])
    } catch {
      // Log error similar to Objective-C implementation? Maybe not needed in Swift directly.
      // FIRLogDebug(...)
      return nil
    }
  }

  // MARK: - NSCopying

  @objc public func copy(with zone: NSZone? = nil) -> Any {
    // Create a new instance with the same data and source.
    let copy = RemoteConfigValue(data: valueData, source: source)
    return copy
  }

  // MARK: - Debug Description

  /// Debug description showing the representations of all types.
  public override var debugDescription: String {
    let jsonString = jsonValue.map { "\($0)" } ?? "nil"
    return "<\(String(describing: type(of: self))): \(Unmanaged.passUnretained(self).toOpaque()), " +
           "Boolean: \(boolValue), String: \(stringValue), Number: \(numberValue), " +
           "JSON: \(jsonString), Data: \(dataValue.count) bytes, Source: \(source.rawValue)>"
  }
}
