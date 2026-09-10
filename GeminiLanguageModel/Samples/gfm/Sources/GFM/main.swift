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

import ArgumentParser
import Darwin
import Foundation
import GFMCore

if #available(macOS 27.0, *) {
  do {
    let command = try await GFMCommand.asyncParseAsRoot()
    try await execute(command)
  } catch {
    GFMCommand.exit(withError: error)
  }
} else {
  fputs("Error: gfm requires macOS 27.0 or newer.\n", stderr)
  exit(1)
}

@available(macOS 27.0, *)
private func execute(_ command: any ParsableCommand) async throws {
  if let asyncCommand = command as? any AsyncParsableCommand {
    try await executeAsync(asyncCommand)
  } else {
    var syncCommand = command
    try syncCommand.run()
  }
}

@available(macOS 27.0, *)
private func executeAsync<C: AsyncParsableCommand>(_ command: C) async throws {
  var asyncCommand = command
  try await asyncCommand.run()
}
