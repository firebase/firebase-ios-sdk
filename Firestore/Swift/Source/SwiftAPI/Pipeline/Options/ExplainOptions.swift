// Copyright 2025 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

public struct ExplainOptions: OptionProtocol, Sendable, Equatable, Hashable {
  public struct Mode: Sendable, Equatable, Hashable {
    let rawValue: String

    public static let execute = Mode(rawValue: "execute")
    public static let explain = Mode(rawValue: "explain")
    public static let analyze = Mode(rawValue: "analyze")

    init(rawValue: String) {
      self.rawValue = rawValue
    }
  }

  public struct OutputFormat: Sendable, Equatable, Hashable {
    let rawValue: String

    public static let text = OutputFormat(rawValue: "text")
    public static let json = OutputFormat(rawValue: "json")
    public static let `struct` = OutputFormat(rawValue: "struct")

    init(rawValue: String) {
      self.rawValue = rawValue
    }
  }

  public struct Verbosity: Sendable, Equatable, Hashable {
    let rawValue: String

    public static let summaryOnly = Verbosity(rawValue: "summary_only")
    public static let executionTree = Verbosity(rawValue: "execution_tree")

    init(rawValue: String) {
      self.rawValue = rawValue
    }
  }

  public struct Profiles: Sendable, Equatable, Hashable {
    let rawValue: String

    public static let latency = Profiles(rawValue: "latency")
    public static let recordsCount = Profiles(rawValue: "records_count")
    public static let bytesThroughput = Profiles(rawValue: "bytes_throughput")

    init(rawValue: String) {
      self.rawValue = rawValue
    }
  }

  public let mode: Mode?
  public let outputFormat: OutputFormat?
  public let verbosity: Verbosity?
  public let indexRecommendation: Bool?
  public let profiles: Profiles?
  public let redact: Bool?

  public init(mode: Mode? = nil,
              outputFormat: OutputFormat? = nil,
              verbosity: Verbosity? = nil,
              indexRecommendation: Bool? = nil,
              profiles: Profiles? = nil,
              redact: Bool? = nil) {
    self.mode = mode
    self.outputFormat = outputFormat
    self.verbosity = verbosity
    self.indexRecommendation = indexRecommendation
    self.profiles = profiles
    self.redact = redact
  }
}
