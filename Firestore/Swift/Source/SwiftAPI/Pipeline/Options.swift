public protocol OptionProtocol: Sendable {}

public struct ExplainOptions: OptionProtocol {
  public var mode: String = ""
  public var outputFormat: String = ""
  public var verbosity: String = ""
  public var indexRecommendation: Bool = false
  public var profiles: String = ""
  public var redact: Bool = false

  public init(mode: String = "",
              outputFormat: String = "",
              verbosity: String = "",
              indexRecommendation: Bool = false,
              profiles: String = "",
              redact: Bool = false) {
    self.mode = mode
    self.outputFormat = outputFormat
    self.verbosity = verbosity
    self.indexRecommendation = indexRecommendation
    self.profiles = profiles
    self.redact = redact
  }
}

public struct GenericOptions: OptionProtocol {
  var values: [String: Sendable]
  public init(_ values: [String: Sendable] = [:]) {
    self.values = values
  }
}

public struct IndexMode: OptionProtocol {
  var values: String
  public init(_ values: String) {
    self.values = values
  }
}

@resultBuilder
public struct OptionBuilder {
  public static func buildBlock(_ components: [OptionProtocol]...) -> [OptionProtocol] {
    components.flatMap { $0 }
  }

  public static func buildOptional(_ components: [OptionProtocol]?) -> [OptionProtocol] {
    components ?? []
  }

  public static func buildExpression(_ components: OptionProtocol) -> [OptionProtocol] {
    [components]
  }

  public static func buildExpression(_ components: [OptionProtocol]) -> [OptionProtocol] {
    components
  }

  public static func buildEither(first components: [OptionProtocol]) -> [OptionProtocol] {
    components
  }

  public static func buildEither(second components: [OptionProtocol]) -> [OptionProtocol] {
    components
  }
}
