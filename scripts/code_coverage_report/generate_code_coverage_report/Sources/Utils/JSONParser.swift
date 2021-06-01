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

import Foundation

public enum JSONParser {
  // Decode an instance from a JSON object.
  public static func readJSON<T: Codable>(of _: T.Type, from data: Data) -> T? {
    do {
      let coverageReportSource = try JSONDecoder().decode(T.self, from: data)
      return coverageReportSource
    } catch {
      print("Data for JSON are not able to be generated: \(error)\n")
    }
    return nil
  }

  // Decode an instance from a JSON file.
  public static func readJSON<T: Codable>(of dataStruct: T.Type, from path: String) -> T? {
    do {
      let fileURL = URL(fileURLWithPath: FileManager().currentDirectoryPath)
        .appendingPathComponent(path)
      let data = try Data(contentsOf: fileURL)
      return readJSON(of: dataStruct, from: data)
    } catch {
      print("\(path) cannot be read: \(error)\n")
    }
    return nil
  }
}
