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

class JSONParser{
    static func readJSON<T: Codable> (of _: T.Type, from data: Data) -> T?{
      do {
        let coverageReportSource = try JSONDecoder().decode(T.self, from: data)
        return coverageReportSource
      } catch {
        print("Data for JSON are not able to be generated: \(error)\n")
      }
      return nil
    }

    static func readJSON<T: Codable> (of dataStruct: T.Type, from path: String) -> T?{
        do{
        let fileURL = URL(fileURLWithPath: FileManager().currentDirectoryPath)
          .appendingPathComponent(path)
        let data = try Data(contentsOf: fileURL)
        return self.readJSON(of: dataStruct, from: data)
        } catch {
        print("\(path) cannot be read: \(error)\n")
        }
        return nil
    }
}

struct FileIncrementalChanges: Codable{

    let file: String
    let addedLines: [Int]

    enum CodingKeys: String, CodingKey {
        case file
        case addedLines = "added_lines"
    }
}

extension FileIncrementalChanges{
    static func dataModel(_ filePath: String) throws -> [FileIncrementalChanges] {
        guard let data = JSONParser.readJSON(of: [FileIncrementalChanges].self, from: filePath) else { throw ValidationError("Badly data transform.")}
        return data
    }
}

struct LineCoverage: Codable {
    var file: String
    var coverage: [Int?]
}

struct IncrementalCoverageReportGenerator: ParsableCommand {

  @Option(
    help: "Root path of archived files in a xcresult bundle."
  )
  var fileArchiveRootPath: String

  @Option(help: "Path of a xcresult bundle.")
  var xcresultPath: String

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
  var uncovered_line_file_json: String = "uncovered_file_lines.json"

  func createLineCoverageRecord(from coverageFile: String, testingFile: String, lineCoverage:[LineCoverage]? = nil) -> [LineCoverage]{
    var coverage: [Int?] = []
    if let dir = URL(string: FileManager.default.currentDirectoryPath){

        let fileURL = dir.appendingPathComponent(coverageFile)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            preconditionFailure("file expected at \(fileURL.absoluteString) is missing")
        }
        guard let filePointer:UnsafeMutablePointer<FILE> = fopen(fileURL.path,"r") else {
            preconditionFailure("Could not open file at \(fileURL.absoluteString)")
        }
        // a pointer to a null-terminated, UTF-8 encoded sequence of bytes
        var lineByteArrayPointer: UnsafeMutablePointer<CChar>? = nil

        // the smallest multiple of 16 that will fit the byte array for this line
        var lineCap: Int = 0

        // initial iteration
        var bytesRead = getline(&lineByteArrayPointer, &lineCap, filePointer)

        defer {
            // remember to close the file when done
            fclose(filePointer)
        }

        let lineCoverageRegex = try! NSRegularExpression(pattern: "([0-9]+)\\s*:\\s*([0-9*]+)")

        while (bytesRead > 0) {
            
            // note: this translates the sequence of bytes to a string using UTF-8 interpretation
            let lineAsString = String.init(cString:lineByteArrayPointer!)
            
            // do whatever you need to do with this single line of text
            // for debugging, can print it
            // print(lineAsString)
            let range = NSRange(location: 0, length: lineAsString.utf16.count)
            if let match = lineCoverageRegex.firstMatch(in: lineAsString, options: [], range: range) {
                let nsRange = match.range(at: 2) 
                if let range = Range(nsRange, in: lineAsString) {
                        // do something with `substring` here
                        // print("regex match : \(String(lineAsString[range]))")
                        // print (lineAsString[range])
                        coverage.append(Int(lineAsString[range]))
                    }
            }
            
            // updates number of bytes read, for the next iteration
            bytesRead = getline(&lineByteArrayPointer, &lineCap, filePointer)
        }
    }
    if var coverageData = lineCoverage {
        coverageData.append(LineCoverage(file: testingFile, coverage: coverage))
        return coverageData
    } else {
        return [LineCoverage(file: testingFile, coverage: coverage)]
    }
  }

  func run() throws {
      var uncovered_files : [LineCoverage?] = []
      let command = "xcrun xccov view --archive --file "
      for change in changedFiles {
          let archiveFilePath = URL(string: fileArchiveRootPath)!.appendingPathComponent(change.file)
          print (archiveFilePath.absoluteString)
          Shell.run("\(command) \(archiveFilePath.absoluteString) \(xcresultPath) > one_file_coverages_buffer.txt 2> /dev/null",displayCommand: false,displayFailureResult: false)
          // Shell.run("\(command) \(archiveFilePath.absoluteString) \(xcresultPath) > test1.txt")
          
          for coverageFile in createLineCoverageRecord(from: "one_file_coverages_buffer.txt", testingFile: change.file) {
              var uncoveredLine: LineCoverage = LineCoverage(file: coverageFile.file, coverage: [])
              for addedLineIndex in change.addedLines{
                  if addedLineIndex < coverageFile.coverage.count { 
                      if let test_cover_run = coverageFile.coverage[addedLineIndex] {
                          if test_cover_run == 0 {uncoveredLine.coverage.append(addedLineIndex)}
                          print ("\(addedLineIndex) : \(test_cover_run)")
                      } 
                  }
              }
              if !uncoveredLine.coverage.isEmpty {uncovered_files.append(uncoveredLine)}
          }
      }
        do{
          let jsonData = try JSONEncoder().encode(uncovered_files)
          try String(data: jsonData, encoding: .utf8)!.write(to: URL(fileURLWithPath: FileManager().currentDirectoryPath).appendingPathComponent(uncovered_line_file_json), atomically: true, encoding: String.Encoding.utf8)
        } catch {
        print("Uncovered lines are not able to be parsed into a JSON file.\n \(error)\n")
        }
  }
}

IncrementalCoverageReportGenerator.main()
