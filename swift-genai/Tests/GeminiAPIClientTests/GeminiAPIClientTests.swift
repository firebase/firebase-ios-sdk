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

import Foundation
import Testing
import InternalSharedDataModels
import InternalGeminiDataModels
@testable import GeminiAPIClient

@Suite struct GeminiDataModelTests {
  @Test func testDecodeUnarySuccessMockResponses() throws {
    let sourceFile = URL(fileURLWithPath: #filePath)
    let packageDir = sourceFile
      .deletingLastPathComponent() // GeminiAPIClientTests
      .deletingLastPathComponent() // Tests
      .deletingLastPathComponent() // Root
    let mockResponsesDir = packageDir.appendingPathComponent("utilities/vertexai-sdk-test-data/mock-responses")
    
    #expect(FileManager.default.fileExists(atPath: mockResponsesDir.path), "Mock responses directory not found. Did the repo clone fail?")
    
    let subDirs = ["googleai", "vertexai"]
    let decoder = JSONDecoder()
    var decodeCount = 0
    
    for subDir in subDirs {
      let dirPath = mockResponsesDir.appendingPathComponent(subDir)
      let files = try FileManager.default.contentsOfDirectory(at: dirPath, includingPropertiesForKeys: nil)
      
      for fileURL in files {
        let filename = fileURL.lastPathComponent
        guard filename.hasSuffix(".json"), filename.hasPrefix("unary-success-") else {
          continue
        }
        
        let data = try Data(contentsOf: fileURL)
        do {
          if filename.contains("token") {
            _ = try decoder.decode(GeminiDataModels.CountTokensResponse.self, from: data)
          } else {
            _ = try decoder.decode(GeminiDataModels.GenerateContentResponse.self, from: data)
          }
          decodeCount += 1
        } catch {
          Issue.record("Failed to decode \(subDir)/\(filename): \(error)")
        }
      }
    }
    
    #expect(decodeCount > 0, "No unary mock responses were found and decoded.")
    print("Successfully decoded \(decodeCount) unary golden mock responses.")
  }

  @Test func testDecodeStreamingSuccessMockResponses() throws {
    let sourceFile = URL(fileURLWithPath: #filePath)
    let packageDir = sourceFile
      .deletingLastPathComponent() // GeminiAPIClientTests
      .deletingLastPathComponent() // Tests
      .deletingLastPathComponent() // Root
    let mockResponsesDir = packageDir.appendingPathComponent("utilities/vertexai-sdk-test-data/mock-responses")
    
    #expect(FileManager.default.fileExists(atPath: mockResponsesDir.path), "Mock responses directory not found. Did the repo clone fail?")
    
    let subDirs = ["googleai", "vertexai"]
    let decoder = JSONDecoder()
    var chunkCount = 0
    
    for subDir in subDirs {
      let dirPath = mockResponsesDir.appendingPathComponent(subDir)
      let files = try FileManager.default.contentsOfDirectory(at: dirPath, includingPropertiesForKeys: nil)
      
      for fileURL in files {
        let filename = fileURL.lastPathComponent
        guard filename.hasSuffix(".txt"), filename.hasPrefix("streaming-success-") else {
          continue
        }
        
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)
        
        for (lineIndex, line) in lines.enumerated() {
          let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
          guard !trimmed.isEmpty else { continue }
          
          guard trimmed.hasPrefix("data:") else {
            Issue.record("Line \(lineIndex + 1) in \(subDir)/\(filename) does not start with 'data:'")
            continue
          }
          
          let jsonString = trimmed.dropFirst(5).trimmingCharacters(in: .whitespacesAndNewlines)
          guard let jsonData = jsonString.data(using: .utf8) else {
            Issue.record("Failed to convert line \(lineIndex + 1) in \(subDir)/\(filename) to UTF8 data")
            continue
          }
          
          do {
            _ = try decoder.decode(GeminiDataModels.GenerateContentResponse.self, from: jsonData)
            chunkCount += 1
          } catch {
            Issue.record("Failed to decode streaming chunk at line \(lineIndex + 1) in \(subDir)/\(filename): \(error)")
          }
        }
      }
    }
    
    #expect(chunkCount > 0, "No streaming mock response chunks were found and decoded.")
    print("Successfully decoded \(chunkCount) streaming golden mock response chunks.")
  }
}
