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

protocol ConvertibleToRequestPayload {
  associatedtype Payload: Encodable

  func toRequestPayload() throws -> Payload
}

extension ConvertibleToRequestPayload {
  func defaultEncode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(toRequestPayload())
  }
}

protocol ConvertibleFromResponsePayload {
  associatedtype Payload: Decodable

  init(_ responsePayload: Payload) throws
}

extension ConvertibleFromResponsePayload {
  init(defaultInitFrom decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    let payload = try container.decode(Payload.self)
    try self.init(payload)
  }
}
