// Copyright 2024 Google LLC
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

import FirebaseCore
import FirebaseDataConnect

enum KitchenSinkError: Error {
  case configureFailed
}

actor ProjectConfigurator {
  static let shared = ProjectConfigurator()

  private init() {}

  private var setupComplete = false

  func configureProject(useDummyEngine: Bool = true) async throws {
    guard !setupComplete else {
      // setup already complete
      return
    }

    guard let resourcePath = Bundle.module.resourcePath
    else { throw KitchenSinkError.configureFailed }
    let projectDirPath = URL(fileURLWithPath: resourcePath)
      .appendingPathComponent("fdc-kitchensink/dataconnect").path

    let configureBody = """
    {
      "service_id": "\(KitchenSinkClient.connectorConfig.serviceId)",
      "config_directory": "\(projectDirPath)",
      "use_dummy": \(useDummyEngine)
    }'

    """

    let configureUrl = URL(string: "http://127.0.0.1:3628/emulator/configure")!
    var configureRequest = URLRequest(url: configureUrl)
    configureRequest.httpMethod = "POST"

    let (data, response) = try await URLSession.shared.upload(
      for: configureRequest,
      from: configureBody.data(using: .utf8)!
    )
    print("responseData \(response)")
    setupComplete = true
  }
}
