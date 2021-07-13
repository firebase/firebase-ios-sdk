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
  static let xcresultExtension = "xcresult"
  // Command to get line execution counts of a file in a xcresult bundle.
  static let xcovCommand = "xcrun xccov view --archive --file "
  // The pattern is to match text "line_index: execution_counts" from the
  // outcome of xcresult bundle, e.g. "305 : 0".
  static let lineExecutionCountPattern = "[0-9]+\\s*:\\s*([0-9*]+)"
  // Match to the group of the lineExecutionCountPattern, i.e "([0-9*]+)".
  static let lineExecutionCountPatternGroup = 1
  // A file includes all newly added lines without tests covered.
  static let defaultUncoveredLineReportFileName = "uncovered_file_lines.json"
}

/// A JSON file from git_diff_to_json.sh will be decoded to the following instance.
struct FileIncrementalChanges: Codable {
  // Name of a file with newly added lines
  let file: String
  // Indices of newly added lines in this file
  let addedLines: [Int]
  enum CodingKeys: String, CodingKey {
    case file
    case addedLines = "added_lines"
  }
}

/// `xccov` outcomes of a file from a xcresult bundle will be transfered
/// to the following instance.
struct LineCoverage: Codable {
  var fileName: String
  // Line execution counts for lines in this file, the indices of the array are
  // the (line indices - 1) of this  file.
  var coverage: [Int?]
  // The source/xcresult bundle of the coverage
  var xcresultBundle: URL
}

struct IncrementalCoverageReportGenerator: ParsableCommand {
  @Option(
    help: "Root path of archived files in a xcresult bundle."
  )
  var fileArchiveRootPath: String

  @Option(help: "A dir of xcresult bundles.",
          transform: URL.init(fileURLWithPath:))
  var xcresultDir: URL

  @Option(
    help: """
    A JSON file with changed files and added line numbers. E.g. JSON file:
    '[{"file": "FirebaseDatabase/Sources/Api/FIRDataSnapshot.m", "added_lines": [105,106,107,108,109]},{"file": "FirebaseDatabase/Sources/Core/Utilities/FPath.m", "added_lines": [304,305,306,307,308,309]}]'
    """,
    transform: { try JSONParser.readJSON(of: [FileIncrementalChanges].self, from: $0) }
  )
  var changedFiles: [FileIncrementalChanges]

  @Option(
    help: "Uncovered line JSON file output path"
  )
  var uncoveredLineFileJson: String = Constants.defaultUncoveredLineReportFileName

  /// This will transfer line executions report from a xcresult bundle to an array of LineCoverage.
  /// The output will have the file name, line execution counts and the xcresult bundle name.
  func createLineCoverageRecord(from coverageFile: URL, changedFile: String,
                                lineCoverage: [LineCoverage]? = nil) -> [LineCoverage] {
    // The indices of the array represent the (line index - 1), while the value is the execution counts.
    // Unexecutable lines, e.g. comments, will be nil here.
    var lineExecutionCounts: [Int?] = []
    do {
      let inString = try String(contentsOf: coverageFile)
      let lineCoverageRegex = try! NSRegularExpression(pattern: Constants
        .lineExecutionCountPattern)
      for line in inString.components(separatedBy: "\n") {
        let range = NSRange(location: 0, length: line.utf16.count)
        if let match = lineCoverageRegex.firstMatch(in: line, options: [], range: range) {
          // Get the execution counts and append. Line indices are
          // consecutive and so the array will have counts for each line
          // and nil for unexecutable lines, e.g. comments.
          let nsRange = match.range(at: Constants.lineExecutionCountPatternGroup)
          if let range = Range(nsRange, in: line) {
            lineExecutionCounts.append(Int(line[range]))
          }
        }
      }
    } catch {
      fatalError("Failed to open \(coverageFile): \(error)")
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

  /// This function is to get union of newly added file lines and lines execution counts, from a xcresult bundle.
  /// Return an array of LineCoverage, which includes uncovered line indices of a file and its xcresult bundle source.
  func getUncoveredFileLines(fromDiff changedFiles: [FileIncrementalChanges],
                             xcresultFile: URL,
                             archiveRootPath rootPath: String) -> [LineCoverage] {
    var uncoveredFiles: [LineCoverage] = []
    for change in changedFiles {
      let archiveFilePath = URL(string: rootPath)!.appendingPathComponent(change.file)
      // tempOutputFile is a temp file, with the xcresult bundle name, including line execution counts of a file
      let tempOutputFile = xcresultFile.deletingPathExtension()
      // Fetch line execution report of a file from a xcresult bundle into a temp file, which has the same name as the xcresult bundle.
      Shell.run(
        "\(Constants.xcovCommand) \(archiveFilePath.absoluteString) \(xcresultFile.path) > \(tempOutputFile.path)",
        displayCommand: true,
        displayFailureResult: false
      )
      for coverageFile in createLineCoverageRecord(
        from: tempOutputFile,
        changedFile: change.file
      ) {
        var uncoveredLine: LineCoverage = LineCoverage(
          fileName: coverageFile.fileName,
          coverage: [],
          xcresultBundle: coverageFile.xcresultBundle
        )
        print("The following lines shown below, if any, are found not tested in \(xcresultFile)")
        for addedLineIndex in change.addedLines {
          // `xccov` report will not involve unexecutable lines which are at
          // the end of the file. That means if the last couple lines are
          // comments, these lines will not be in the `coverageFile.coverage`.
          // Indices in an array, starting from 0,  correspond to lineIndex,
          // starting from 0, minus 1.
          if addedLineIndex <= coverageFile.coverage.count,
            let testCoverRun = coverageFile.coverage[addedLineIndex - 1], testCoverRun == 0 {
            print(addedLineIndex)
            uncoveredLine.coverage.append(addedLineIndex)
          }
        }
        if !uncoveredLine.coverage.isEmpty { uncoveredFiles.append(uncoveredLine) }
      }
    }
    return uncoveredFiles
  }

  func run() throws {
    let enumerator = FileManager.default.enumerator(atPath: xcresultDir.path)
    var uncoveredFiles: [LineCoverage] = []
    // Search xcresult bundles from xcresultDir and get union of `git diff` report and xccov output to generate a list of lineCoverage including files and their uncovered lines.
    while let file = enumerator?.nextObject() as? String {
      var isDir: ObjCBool = false
      let xcresultURL = xcresultDir.appendingPathComponent(file, isDirectory: true)
      if FileManager.default.fileExists(atPath: xcresultURL.path, isDirectory: &isDir) {
        if isDir.boolValue, xcresultURL.path.hasSuffix(Constants.xcresultExtension) {
          let uncoveredXcresult = getUncoveredFileLines(
            fromDiff: changedFiles,
            xcresultFile: xcresultURL,
            archiveRootPath: fileArchiveRootPath
          )
          uncoveredFiles.append(contentsOf: uncoveredXcresult)
        }
      }
    }
    // Output uncoveredFiles as a JSON file.
    do {
      let jsonData = try JSONEncoder().encode(uncoveredFiles)
      try String(data: jsonData, encoding: .utf8)!.write(
        to: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
          .appendingPathComponent(uncoveredLineFileJson),
        atomically: true,
        encoding: String.Encoding.utf8
      )
    } catch {
      print("Uncovered lines are not able to be parsed into a JSON file.\n \(error)\n")
    }
  }
}

IncrementalCoverageReportGenerator.main()
