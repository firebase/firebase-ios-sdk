/*
 * Copyright 2021 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import ArgumentParser
import Foundation
import Utils

private enum Constants {}

extension Constants {
  static let XCRESULT_EXTENSION = "xcresult"
  // Command to get line execution counts of a file in a xcresult bundle.
  static let XCOV_COMMAND = "xcrun xccov view --archive --file "
  // The pattern is to match text "line_index: execution_counts" from the
  // outcome of xcresult bundle, e.g. "305 : 0".
  static let LINE_EXECUTION_COUNT_PATTERN = "([0-9]+)\\s*:\\s*([0-9*]+)"
  // A file includes all newly added lines without tests covered.
  static let DEFAULT_UNCOVERED_LINE_REPORT_FILE_NAME = "uncovered_file_lines.json"
}

struct FileIncrementalChanges: Codable {
  let file: String
  let addedLines: [Int]
  enum CodingKeys: String, CodingKey {
    case file
    case addedLines = "added_lines"
  }
}

extension FileIncrementalChanges {
  static func dataModel(_ filePath: String) throws -> [FileIncrementalChanges] {
    guard let data = JSONParser.readJSON(of: [FileIncrementalChanges].self, from: filePath)
    else { throw ValidationError("Badly data transform.") }
    return data
  }
}

struct LineCoverage: Codable {
  var fileName: String
  var coverage: [Int?]
  var xcresultBundle: String
}

struct IncrementalCoverageReportGenerator: ParsableCommand {
  @Option(
    help: "Root path of archived files in a xcresult bundle."
  )
  var fileArchiveRootPath: String

  @Option(help: "A dir of xcresult bundles.")
  var xcresultDir: String

  @Option(
    help: """
    A JSON file with changed files and added line numbers. E.g. JSON file:
    '[{"file": "FirebaseDatabase/Sources/Api/FIRDataSnapshot.m", "added_lines": [105,106,107,108,109]},{"file": "FirebaseDatabase/Sources/Core/Utilities/FPath.m", "added_lines": [304,305,306,307,308,309]}]'
    """,
    transform: FileIncrementalChanges.dataModel
  )
  var changedFiles: [FileIncrementalChanges]

  @Option(
    help: "Uncovered line JSON file output path"
  )
  var uncovered_line_file_json: String = Constants.DEFAULT_UNCOVERED_LINE_REPORT_FILE_NAME

  func readFile(_ fileURL: URL) -> String {
    var fileContent = ""
    do {
      fileContent = try String(contentsOf: fileURL)
    } catch {
      print("Failed reading from URL: \(fileURL), Error: " + error.localizedDescription)
    }
    return fileContent
  }

  // This will transfer line executions report from a xcresult bundle to an array of LineCoverage.
  // The output will have the file name, line execution counts and the xcresult bundle name.
  func createLineCoverageRecord(from coverageFile: String, changedFile: String,
                                lineCoverage: [LineCoverage]? = nil) -> [LineCoverage] {
    // The indices of the array represent the (line index - 1), while the value is the execution counts.
    var lineExecutionCounts: [Int?] = []
    if let dir = URL(string: "file://" + FileManager.default.currentDirectoryPath) {
      let fileURL = dir.appendingPathComponent(coverageFile)
      let inString = readFile(fileURL)
      let lineCoverageRegex = try! NSRegularExpression(pattern: Constants
        .LINE_EXECUTION_COUNT_PATTERN)
      for line in inString.components(separatedBy: "\n") {
        let range = NSRange(location: 0, length: line.utf16.count)
        if let match = lineCoverageRegex.firstMatch(in: line, options: [], range: range) {
          // Get the execution counts and append. Line indices are
          // consecutive and so the array will have counts for each line
          // and nil for unexecutable lines, e.g. comments.
          let nsRange = match.range(at: 2)
          if let range = Range(nsRange, in: line) {
            lineExecutionCounts.append(Int(line[range]))
          }
        }
      }
    }
    if var coverageData = lineCoverage {
      coverageData
        .append(LineCoverage(fileName: changedFile, coverage: lineExecutionCounts,
                             xcresultBundle: coverageFile))
      return coverageData
    } else {
      return [LineCoverage(fileName: changedFile, coverage: lineExecutionCounts,
                           xcresultBundle: coverageFile)]
    }
  }

  // This function is to get union of newly added file lines and lines execution counts, from a xcresult bundle.
  // Return an array of LineCoverage, which includes uncovered line indices of a file and its xcresult bundle source.
  func get_uncovered_file_lines(fromDiff changedFiles: [FileIncrementalChanges],
                                fromXcresult xcresultPath: String,
                                archiveRootPath rootPath: String) -> [LineCoverage?] {
    var uncovered_files: [LineCoverage?] = []
    for change in changedFiles {
      let archiveFilePath = URL(string: rootPath)!.appendingPathComponent(change.file)
      print(archiveFilePath.absoluteString)
      // temp_output_file is a temp file, with the xcresult bundle name, including line execution counts of a file
      let temp_output_file = URL(fileURLWithPath: xcresultPath).deletingPathExtension()
        .lastPathComponent
      // Fetch line execution report of a file from a xcresult bundle into a temp file, which has the same name as the xcresult bundle.
      Shell.run(
        "\(Constants.XCOV_COMMAND) \(archiveFilePath.absoluteString) \(xcresultPath) > \(temp_output_file)",
        displayCommand: true,
        displayFailureResult: false
      )
      for coverageFile in createLineCoverageRecord(
        from: "\(temp_output_file)",
        changedFile: change.file
      ) {
        var uncoveredLine: LineCoverage = LineCoverage(
          fileName: coverageFile.fileName,
          coverage: [],
          xcresultBundle: coverageFile.xcresultBundle
        )
        for addedLineIndex in change.addedLines {
          if addedLineIndex < coverageFile.coverage.count {
            if let test_cover_run = coverageFile.coverage[addedLineIndex] {
              if test_cover_run == 0 { uncoveredLine.coverage.append(addedLineIndex) }
              print("\(addedLineIndex) : \(test_cover_run)")
            }
          }
        }
        if !uncoveredLine.coverage.isEmpty { uncovered_files.append(uncoveredLine) }
      }
    }
    return uncovered_files
  }

  func run() throws {
    let enumerator = FileManager.default.enumerator(atPath: xcresultDir)
    var uncovered_files: [LineCoverage?] = []
    // Search xcresult bundles from xcresultDir and get union of `git diff` report and xccov output to generate a list of lineCoverage including files and their uncovered lines.
    while let file = enumerator?.nextObject() as? String {
      var isDir: ObjCBool = false
      let absoluteFilePath = xcresultDir + file
      if FileManager.default.fileExists(atPath: absoluteFilePath, isDirectory: &isDir) {
        if isDir.boolValue, absoluteFilePath.hasSuffix(Constants.XCRESULT_EXTENSION) {
          let uncovered_xcresult = get_uncovered_file_lines(
            fromDiff: changedFiles,
            fromXcresult: absoluteFilePath,
            archiveRootPath: fileArchiveRootPath
          )
          uncovered_files.append(contentsOf: uncovered_xcresult)
        }
      }
    }
    // Output uncovered_files as a JSON file.
    do {
      let jsonData = try JSONEncoder().encode(uncovered_files)
      try String(data: jsonData, encoding: .utf8)!.write(
        to: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
          .appendingPathComponent(uncovered_line_file_json),
        atomically: true,
        encoding: String.Encoding.utf8
      )
    } catch {
      print("Uncovered lines are not able to be parsed into a JSON file.\n \(error)\n")
    }
  }
}

IncrementalCoverageReportGenerator.main()
