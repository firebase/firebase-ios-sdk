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

import Foundation
import ArgumentParser

struct SpmLocalizer: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Updates an Xcode project's firebase-ios-sdk SPM dependency to point to a specific version, branch, or commit."
    )

    @Argument(help: "Path to the .xcodeproj file.")
    var projectPath: String

    @Option(name: .long, help: "The version to use for release testing (e.g., '10.24.0').")
    var version: String?

    @Flag(name: .long, help: "Flag to point to the latest commit on the main branch for prerelease testing.")
    var prerelease = false

    @Option(name: .long, help: "The commit hash to use for PR/branch testing.")
    var revision: String?

    func run() throws {
        let pbxprojPath = "\(projectPath)/project.pbxproj"
        var pbxprojContents: String
        do {
            pbxprojContents = try String(contentsOfFile: pbxprojPath, encoding: .utf8)
        } catch {
            fatalError("Failed to read project.pbxproj file: \(error)")
        }

        let requirement: String
        let indent4 = "\t\t\t\t"
        let indent3 = "\t\t\t"
        if let version = version {
            // Release testing: Point to CocoaPods-{VERSION} tag (as a branch)
            requirement = "{\n\(indent4)kind = branch;\n\(indent4)branch = \"CocoaPods-\(version)\";\n\(indent3)}"
        } else if prerelease {
            // Prerelease testing: Point to the tip of the main branch
            let commitHash = try getRemoteHeadRevision(branch: "main")
            requirement = "{\n\(indent4)kind = revision;\n\(indent4)revision = \"\(commitHash)\";\n\(indent3)}"
        } else if let revision = revision {
            // PR testing: Point to the specific commit hash of the current branch
            requirement = "{\n\(indent4)kind = revision;\n\(indent4)revision = \"\(revision)\";\n\(indent3)}"
        } else {
            fatalError("No dependency requirement specified. Please provide --version, --prerelease, or --revision.")
        }

        let updatedContents = try replaceDependency(in: pbxprojContents, with: requirement)

        do {
            try updatedContents.write(toFile: pbxprojPath, atomically: true, encoding: .utf8)
            print("Successfully updated SPM dependency in \(pbxprojPath)")
        } catch {
            fatalError("Failed to write updated contents to project.pbxproj: \(error)")
        }
    }

    private func replaceDependency(in content: String, with requirement: String) throws -> String {
        let pattern = #"(repositoryURL = "https://github.com/firebase/firebase-ios-sdk";\s*requirement = )\{[^\}]+\};"#
        let regex = try NSRegularExpression(pattern: pattern, options: [])

        let range = NSRange(content.startIndex..<content.endIndex, in: content)
        let template = "$1\(requirement);"
        
        let modifiedContent = regex.stringByReplacingMatches(in: content, options: [], range: range, withTemplate: template)

        if content == modifiedContent {
            fatalError("Failed to find and replace the firebase-ios-sdk dependency. Check the regex pattern and project file structure.")
        }
        
        return modifiedContent
    }

    private func getRemoteHeadRevision(branch: String) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["ls-remote", "https://github.com/firebase/firebase-ios-sdk.git", branch]

        let pipe = Pipe()
        process.standardOutput = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8), !output.isEmpty else {
            fatalError("Failed to get remote revision for branch '\(branch)'. No output from git.")
        }

        // Output is in the format: <hash>\trefs/heads/<branch>
        let components = output.components(separatedBy: CharacterSet.whitespacesAndNewlines)
        if components.isEmpty {
            fatalError("Invalid output from git ls-remote: \(output)")
        }
        return components[0]
    }
}

SpmLocalizer.main()
