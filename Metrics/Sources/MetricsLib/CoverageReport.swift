import Foundation

public struct CoverageReport : Decodable {
  public var targets: [Target]
  public var coverage: Double

  public init(targets: [Target], coverage: Double) {
    self.targets = targets
    self.coverage = coverage
  }

  public static func load(path: String) throws -> CoverageReport {
    let data = try Data(contentsOf: NSURL(fileURLWithPath: path) as URL)
    let decoder = JSONDecoder()
    return try decoder.decode(CoverageReport.self, from: data)
  }
}

public struct Target : Decodable {
  public var name: String
  public var files: [File]
  public var coverage: Double

  public init(name: String, coverage: Double) {
    self.name = name
    self.coverage = coverage
    self.files = []
  }
}

public struct File : Decodable {
  public var name: String
  public var coverage: Double
  public var type: String
  public var functions: [Function]
}

public struct Function : Decodable {
  public var name: String
  public var coverage: Double
}
