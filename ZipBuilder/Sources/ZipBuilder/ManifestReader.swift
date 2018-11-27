import Foundation

/// Common functions for Firebase iOS SDK Release manifests. Intentionally empty, this enum is used
/// as a namespace.
enum ManifestReader {}

extension ManifestReader {
   /// Load all the publicly released SDKs and their versions. Will cause a fatal error if the file
   /// cannot be read or proto cannot be generated.
  static func loadAllReleasedSDKs(fromTextproto textproto: URL) -> ZipBuilder_FirebaseSDKs {
    // Read the textproto and create it from the proto's generated API. Fail if anything fails in
    // the process.
    do {
      let protoText = try String(contentsOf: textproto, encoding: .utf8)
      // Internally the `build_flags` field is named `blaze_flags`. Replace it.
      let blazelessText = protoText.replacingOccurrences(of: "blaze_flags", with: "build_flags")
      let proto = try ZipBuilder_FirebaseSDKs(textFormatString: blazelessText)
      return proto
    } catch {
      fatalError("Could not create proto from file containing all released SDKs: \(error)")
    }
  }

  /// Load the current release manifest for the SDKs that are slated for release. Will cause a fatal
  /// error if the file cannot be read or proto cannot be generated.
  ///
  /// - Parameter textproto: The path to the textproto file describing the current release.
  /// - Returns: An instance of ZipBuilder_Release describing specific versions to build.
  static func loadCurrentRelease(fromTextproto textproto: URL) -> ZipBuilder_Release {
    // Read the textproto and create it from the proto's generated API. Fail if anything fails in
    // the process.
    do {
      let protoText = try String(contentsOf: textproto, encoding: .utf8)
      let proto = try ZipBuilder_Release(textFormatString: protoText)
      return proto
    } catch {
      fatalError("Could not create proto from current release manifest: \(error)")
    }
  }
}
