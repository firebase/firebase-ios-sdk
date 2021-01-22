import Foundation

// This will contain code coverage result from a xcresult bundle.
struct CoverageReportSource: Codable{

  let coveredLines: Int
  let lineCoverage: Double
  let targets: [Target]

  struct Target: Codable{
    let name: String
    let files: [File]
    struct File: Codable{

      let coveredLines: Int
      let lineCoverage: Double
      let path: String
      let name: String
    }
  }
}

// This will contains data that will be eventually transferred to a json file
// sent to the Metrics Service.
struct CoverageReportRequestData: Codable{
  var metric: String
  var results: [FileCoverage]
  var log: String

  struct FileCoverage: Codable{
    let sdk: String
    let type: String
    let value: Double
  }
}

// In the tool here, this will contain add all CoverageReportSource objects from
// different xcresult bundles.
extension CoverageReportRequestData{
  init() {
    self.metric = "Coverage"
    self.results = []
    self.log = ""
  }

  mutating func addCoverageData(from source: CoverageReportSource, resultBundle: String){
    for target in source.targets{
      for file in target.files{
        self.results.append(FileCoverage(sdk:resultBundle + "-" + target.name, type: file.name, value: file.lineCoverage))
      }
    }
  }

  mutating func addLogLink(_ logLink: String){
    self.log = logLink
  }

  func toData() -> Data{
    let jsonData = try! JSONEncoder().encode(self)
    return jsonData
  }
}

struct Shell {
  static let shared = Shell()
  @discardableResult
  func run(_ command: String, displayCommand: Bool = true,
           displayFailureResult: Bool = true) -> Int32 {
    let task = Process()
    let pipe = Pipe()
    task.standardOutput = pipe
    task.launchPath = "/bin/zsh"
    task.arguments = ["-c", command]
    task.launch()
    if displayCommand {
      print("[CoverageReportParser] Command:\(command)\n")
    }
    task.waitUntilExit()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let log = String(data: data, encoding: .utf8)!
    if displayFailureResult, task.terminationStatus != 0 {
      print("-----Exit code: \(task.terminationStatus)")
      print("-----Log:\n \(log)")
    }
    return task.terminationStatus
  }
}

// Read json file and transfer to CoverageReportSource.
func readLocalFile(forName name: String) -> CoverageReportSource? {
  do {
      let fileURL = URL(fileURLWithPath: FileManager().currentDirectoryPath).appendingPathComponent(name)
      let data = try Data(contentsOf: fileURL)
      let coverageReportSource = try JSONDecoder().decode(CoverageReportSource.self, from: data)
      return coverageReportSource
  } catch {
      print("CoverageReportSource is not able to be generated. \(error)")
  }
    
  return nil
}

// Get in the dir, xcresultDirPathURL, which contains all xcresult bundles, and
// create CoverageReportRequestData which will have all coverage data for in
// the dir.
func combineCodeCoverageResultBundles(from xcresultDirPathURL: URL) -> CoverageReportRequestData?{
  let fileManager = FileManager.default
  do {
    var coverageReportRequestData = CoverageReportRequestData()
    let fileURLs = try fileManager.contentsOfDirectory( at: xcresultDirPathURL, includingPropertiesForKeys: nil)
    let xcresultURLs = fileURLs.filter { $0.pathExtension == "xcresult" }
    for xcresultURL in xcresultURLs {
      let resultBundleName = xcresultURL.deletingPathExtension().lastPathComponent
      let coverageSourceJSONFile =  "\(resultBundleName).json"
      try? fileManager.removeItem(atPath: coverageSourceJSONFile )
      Shell().run("xcrun xccov view --report --json \(xcresultURL.path) >> \(coverageSourceJSONFile)")
      if let coverageReportSource = readLocalFile(forName: "\(coverageSourceJSONFile)"){
        coverageReportRequestData.addCoverageData(from: coverageReportSource, resultBundle: resultBundleName)
      }
    }
    return coverageReportRequestData
  }
  catch {
    print(
      "Error while enuermating files \(xcresultDirPathURL): \(error.localizedDescription)"
    )
  }
  return nil

}
