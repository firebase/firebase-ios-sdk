import Foundation

/// The output content modality.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public struct OutputContentModality: EncodableProtoEnum, Sendable {
  enum Kind: String {
    case text = "TEXT"
    case image = "IMAGE"
    case audio = "AUDIO"
  }

  /// Text output modality.
  public static let text = OutputContentModality(kind: .text)

  /// Image output modality.
  public static let image = OutputContentModality(kind: .image)
  
  /// Audio output modality.
  public static let audio = OutputContentModality(kind: .audio)

  let rawValue: String

  private init(kind: Kind) {
    self.rawValue = kind.rawValue
  }
}
