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

import FirebaseCore
import Foundation

/// Handles the formatting and network dispatch of telemetry data payloads.
internal struct TelemetryUploader: @unchecked Sendable {
  /// The telemetry data types that should be supported for export.
  /// Currently only Traces are supported.
  private enum TelemetryType: String {
    case traces = "traces"
    case logs = "logs"
  }

  private let options: FirebaseOptions

  private static let baseExportEndpoint = URL(
    string: "https://firebasetelemetry.googleapis.com"
  )!

  /// Initializes the telemetry uploader.
  ///
  /// - Parameter options: The FirebaseOptions used to construct endpoint URLs and authenticate requests.
  public init(options: FirebaseOptions) {
    self.options = options
  }

  /// Uploads a serizalized payload of trace export request.
  ///
  /// This is not a robust implementation as we might decide to use GDT for this purpose.
  ///
  /// - Parameter payload: The serialized payload to upload.
  /// - Throws: An error if URL generation, serialization, or the network request fails.
  public func uploadTrace(
    _ payload: Data
  ) async throws {
    let endpoint = try buildEndpointURL(for: .traces)
    let request = try createURLRequest(to: endpoint, payload: payload)

    try await execute(request)
  }

  /// Constructs the appropriate remote endpoint URL for the given telemetry type.
  ///
  /// - Parameter type: The type of telemetry data being exported (e.g., traces, logs).
  /// - Returns: A fully constructed `URL` for the target environment.
  /// - Throws: `URLError` if the required `projectID` is missing from the Firebase options.
  private func buildEndpointURL(for type: TelemetryType) throws -> URL {
    guard let projectID = options.projectID else {
      LoggingHelper.logger.error("Generating Export request failed. Missing Project ID.")
      throw URLError(.badURL)
    }

    return Self.baseExportEndpoint
      .appendingPathComponent("v1")
      .appendingPathComponent("projects")
      .appendingPathComponent(projectID)
      .appendingPathComponent("apps")
      .appendingPathComponent(options.googleAppID)
      .appendingPathComponent("locations")
      .appendingPathComponent("global")
      .appendingPathComponent(type.rawValue)
  }

  /// Creates an authenticated URLRequest with the necessary headers for the backend.
  ///
  /// - Parameters:
  ///   - to: The destination URL.
  ///   - payload: The serialized protobuf payload.
  /// - Returns: A fully configured `URLRequest`.
  /// - Throws: `URLError` if the required `apiKey` is missing from the Firebase configuration.
  private func createURLRequest(to endpoint: URL, payload: Data) throws -> URLRequest {
    guard let apiKey = options.apiKey else {
      LoggingHelper.logger.error("Generating Export request failed. Missing API Key.")
      throw URLError(.userAuthenticationRequired)
    }

    var request = URLRequest(url: endpoint)
    request.httpMethod = "POST"
    request.setValue("application/x-protobuf", forHTTPHeaderField: "Content-Type")
    request.setValue(apiKey, forHTTPHeaderField: "X-Goog-Api-Key")
    request.httpBody = payload

    return request
  }

  /// Dispatches the network request and validates the server response.
  ///
  /// - Parameter request: The configured URLRequest to execute.
  /// - Throws: An error if the network call fails.
  private func execute(_ request: URLRequest) async throws {
    let (data, response) = try await URLSession.shared.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw URLError(.badServerResponse)
    }

    if !(200...299).contains(httpResponse.statusCode) {
      LoggingHelper.logger.error(
        "Telemetry export failed with status code \(httpResponse.statusCode)")
      if let errorMessage = String(data: data, encoding: .utf8), !errorMessage.isEmpty {
        LoggingHelper.logger.error("Server error message: \(errorMessage)")
      }
      throw URLError(.badServerResponse)
    }
  }
}
