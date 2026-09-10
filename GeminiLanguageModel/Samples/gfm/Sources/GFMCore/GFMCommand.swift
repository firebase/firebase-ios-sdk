// Copyright 2026 Google LLC
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

public import ArgumentParser
import Foundation

#if canImport(FoundationModels) && compiler(>=6.4)
  import FoundationModels

  /// The root command for the `gfm` command-line utility.
  @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
  @available(tvOS, unavailable)
  public struct GFMCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
      commandName: "gfm",
      abstract: "Gemini and Apple Foundation Models CLI",
      version: "1.0.0",
      subcommands: [
        AvailableCommand.self,
        ChatCommand.self,
        RespondCommand.self,
        SchemaCommand.self,
      ]
    )

    public init() {}
  }
#endif
