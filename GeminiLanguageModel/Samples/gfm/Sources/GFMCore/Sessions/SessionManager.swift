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

public import Foundation

#if canImport(FoundationModels) && compiler(>=6.4)
  public import FoundationModels

  /// Manages saving, resuming, and discovering chat sessions and transcripts in `~/.fm/sessions/`.
  @available(macOS 27.0, iOS 27.0, watchOS 27.0, visionOS 27.0, *)
  @available(tvOS, unavailable)
  public struct SessionManager: Sendable {
    /// The default directory where interactive chat sessions are stored.
    public let sessionsDirectory: URL

    /// Initializes a new session manager with an optional custom sessions directory.
    ///
    /// - Parameter sessionsDirectory: Directory for storing session JSON files. Defaults to
    ///   `~/.fm/sessions/`.
    public init(sessionsDirectory: URL? = nil) {
      if let sessionsDirectory {
        self.sessionsDirectory = sessionsDirectory
      } else {
        #if os(macOS)
          let homeDir = FileManager.default.homeDirectoryForCurrentUser
        #else
          let homeDir = URL(fileURLWithPath: NSHomeDirectory())
        #endif
        self.sessionsDirectory =
          homeDir
          .appendingPathComponent(".fm", isDirectory: true)
          .appendingPathComponent("sessions", isDirectory: true)
      }
    }

    /// Ensures that the sessions directory exists on the filesystem.
    public func ensureSessionsDirectoryExists() throws {
      try FileManager.default.createDirectory(
        at: sessionsDirectory,
        withIntermediateDirectories: true
      )
    }

    /// Resolves the URL for a session name or file path.
    ///
    /// - Parameter nameOrPath: Either a session identifier (e.g. `"my-session"`) or a file path.
    /// - Returns: The resolved file `URL`.
    public func resolveSessionURL(for nameOrPath: String) -> URL {
      if nameOrPath.hasPrefix("/") || nameOrPath.hasPrefix("~") || nameOrPath.contains("/") {
        let expanded = NSString(string: nameOrPath).expandingTildeInPath
        return URL(fileURLWithPath: expanded)
      }
      let filename = nameOrPath.hasSuffix(".json") ? nameOrPath : "\(nameOrPath).json"
      return sessionsDirectory.appendingPathComponent(filename)
    }

    /// Saves a transcript to the sessions directory or target path.
    ///
    /// - Parameters:
    ///   - transcript: The `Transcript` to encode and save.
    ///   - nameOrPath: The session name or explicit file path.
    public func saveSession(transcript: Transcript, nameOrPath: String) throws {
      try ensureSessionsDirectoryExists()
      let fileURL = resolveSessionURL(for: nameOrPath)
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
      let data = try encoder.encode(transcript)
      try data.write(to: fileURL, options: .atomic)
    }

    /// Loads a transcript from the sessions directory or specified file path.
    ///
    /// - Parameter nameOrPath: The session name or file path to load.
    /// - Returns: The decoded `Transcript`.
    public func loadSession(nameOrPath: String) throws -> Transcript {
      let fileURL = resolveSessionURL(for: nameOrPath)
      let data = try Data(contentsOf: fileURL)
      return try JSONDecoder().decode(Transcript.self, from: data)
    }

    /// Returns the name of the most recently modified session in the sessions directory.
    ///
    /// - Returns: The session name without the `.json` extension, or `nil` if no sessions exist.
    public func mostRecentSessionName() throws -> String? {
      guard FileManager.default.fileExists(atPath: sessionsDirectory.path) else {
        return nil
      }
      let contents = try FileManager.default.contentsOfDirectory(
        at: sessionsDirectory,
        includingPropertiesForKeys: [.contentModificationDateKey],
        options: [.skipsHiddenFiles]
      )
      let jsonFiles = contents.filter { $0.pathExtension == "json" }
      let sorted = jsonFiles.compactMap { url -> (URL, Date)? in
        guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey]),
          let date = values.contentModificationDate
        else {
          return nil
        }
        return (url, date)
      }.sorted { $0.1 > $1.1 }

      guard let mostRecent = sorted.first else {
        return nil
      }
      return mostRecent.0.deletingPathExtension().lastPathComponent
    }

    /// Lists all available saved session names.
    ///
    /// - Returns: An array of session names sorted alphabetically.
    public func listSessionNames() throws -> [String] {
      guard FileManager.default.fileExists(atPath: sessionsDirectory.path) else {
        return []
      }
      let contents = try FileManager.default.contentsOfDirectory(
        at: sessionsDirectory,
        includingPropertiesForKeys: nil,
        options: [.skipsHiddenFiles]
      )
      return
        contents
        .filter { $0.pathExtension == "json" }
        .map { $0.deletingPathExtension().lastPathComponent }
        .sorted()
    }
  }
#endif
