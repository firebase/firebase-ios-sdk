import Foundation

let JAR_URL = "https://storage.googleapis.com/firebase-engprod-metrics/upload_tool.jar"
let JAR_LOCAL_PATH = "upload.jar"
let DATABASE_CONFIG = "database.config"
let JSON_PATH = "database.json"

/// Uploads metrics to the Cloud SQL database.
public class Uploader {
  /// Uploads the provided metrics to the Cloud SQL database.
  public class func upload(metrics: UploadMetrics) throws {
    let jar = try downloadJar()
    let json = try writeJson(metrics: metrics)

    let returnCode = runJar(jar: jar, json: json, config: DATABASE_CONFIG)
    if returnCode == 0 {
      print("Successfully uploaded metrics!")
    } else {
      print("Failed to upload metrics... return code is \(returnCode).")
    }

    try FileManager.default.removeItem(atPath: jar)
    try FileManager.default.removeItem(atPath: json)
  }

  private class func writeJson(metrics: UploadMetrics) throws -> String {
    try metrics.json().write(to: NSURL(fileURLWithPath: JSON_PATH) as URL,
                             atomically: false,
                             encoding: .utf8)
    return JSON_PATH
  }

  private class func downloadJar() throws -> String {
    let jarData = try Data(contentsOf: URL(string: JAR_URL)!)
    try jarData.write(to: NSURL(fileURLWithPath: JAR_LOCAL_PATH) as URL)
    return JAR_LOCAL_PATH
  }

  private class func runJar(jar: String, json: String, config: String) -> Int32 {
    let task = Process()
    task.launchPath = "/usr/bin/java"
    task.arguments = ["-jar", jar, "--json_path=\(json)", "--config_path=\(config)"]
    task.launch()
    task.waitUntilExit()
    return task.terminationStatus
  }
}
