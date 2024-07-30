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

@testable import FirebaseCore
@testable import FirebaseDataConnect

import XCTest

enum GQLData {
  
  static let schema = """
  type UUIDTest @table {
    id: UUID!
  }
  """
  
  static let operations = """
  mutation createUUIDTest($id: UUID!) @auth(level: PUBLIC) {
    uuidtest_create(data : {
      id: $id
    }
  }

  query getUUIDTest @auth(level: PUBLIC) {
    uuidTests {
      id
    }
  }
"""

  static let setupData = """
  {
    "service_id": "kitchensink",
    "schema": {
      "files": [
        {
           "path": "schema/post.gql",
           "content": "type Post @table {content: String!}"
        }
      ]
    },
    "connectors": {
      "crud": {
        "files": [
          {
            "path": "operations/post.gql",
            "content": "query getPost($id: UUID!) @auth(level: PUBLIC) {post(id: $id) {content}} query listPosts @auth(level: PUBLIC) {posts {content}} mutation createPost($id: UUID!, $content: String!) @auth(level: PUBLIC)  {post_insert(data: {id: $id, content: $content})} mutation deletePost($id: UUID!) @auth(level: PUBLIC) { post_delete(id: $id)}"
          }
        ]
      }
    }
  }

"""

}

struct SetupServiceRequest: Codable {
  
  struct GQLFile: Codable {
    var path: String
    var content: String
  }

  struct GQLContent: Codable {
    var files = [GQLFile]()
  }

  var serviceId: String
  var schema: GQLContent

  // connectorId => GQLContent
  var connectors = [String: GQLContent]()

}


extension DataConnect {

}

public class TestConnectorClient {

  var dataConnect: DataConnect

  public static let connectorConfig = ConnectorConfig(serviceId: "kitchensink", location: "us-central1", connector: "crud")

  init(dataConnect: DataConnect) {
    self.dataConnect = dataConnect
  }

  public func useEmulator(host: String = DataConnect.EmulatorDefaults.host, port: Int = DataConnect.EmulatorDefaults.port) {
    self.dataConnect.useEmulator(host: host, port: port)
  }

}

enum CreatePost {
  struct Variables: OperationVariable {
    var id: UUID
    var content: String
  }


  struct Data: Decodable {
    struct PostInsert: Decodable {
      var id: String
    }
    var post_insert: PostInsert
  }
}

extension TestConnectorClient {

}


class IntegrationTests: XCTestCase {

  var dataConnect: DataConnect?
  let connectorConfig = ConnectorConfig(serviceId: "kitchensink", location: "us-central1", connector: "crud")

  override func setUp(completion: @escaping ((any Error)?) -> Void) {
    print("In Setup")

    let options = FirebaseOptions(googleAppID: "0:0000000000000:ios:0000000000000000",
                                  gcmSenderID: "00000000000000000-00000000000-000000000")
    options.projectID = "fdc-test"
    FirebaseApp.configure(options: options)

    dataConnect = DataConnect.dataConnect(app: FirebaseApp.app(), connectorConfig: TestConnectorClient.connectorConfig)
    dataConnect?.useEmulator()

    let url = URL(string: "http://127.0.0.1:9399/setupSchema")!
    var urlRequest = URLRequest(url: url)
    urlRequest.httpMethod = "POST"
    let setupData = GQLData.setupData.data(using: .utf8)!
    let task = URLSession.shared.uploadTask(with: urlRequest, from: setupData) { data, response, error in
      print("uploadTask complete \(error)")
      if let data {
        print("response Data \(String(data: data, encoding: .utf8))")
      }
      completion(error)
    }
    task.resume()

  }

  func testCreatePost() async throws {
    guard let dataConnect else {
      XCTFail("DataConnect instance is not setup and is nil")
      return
    }

    let id = UUID()
    let variables = CreatePost.Variables(id: id, content: "Hello World")
    let request = MutationRequest(operationName: "createPost", variables: variables)
    let ref = dataConnect.mutation(request: request, resultsDataType:CreatePost.Data.self)
    let result = try await ref.execute()
    let idString = result.data.post_insert.id
    let uuidConverter = UUIDCodableConverter()
    let uuid = try uuidConverter.decode(input: idString)
    XCTAssertEqual(uuid, id)
  }

}
