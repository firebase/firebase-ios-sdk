import Foundation

/// Represents the different content modalities that can be used in a response.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public struct ContentModality: Codable, Hashable {
    let rawValue: String

    public static let text = ContentModality(rawValue: "TEXT")
    public static let image = ContentModality(rawValue: "IMAGE")
    public static let audio = ContentModality(rawValue: "AUDIO")
    
    public func hash(into hasher: inout Hasher) -> Int {
        return rawValue.hashValue
    }

    init(rawValue: String) {
        self.rawValue = rawValue
    }
}

extension ContentModality: Equatable {
    public static func == (lhs: ContentModality, rhs: ContentModality) -> Bool {
        return lhs.rawValue == rhs.rawValue
    }
}
