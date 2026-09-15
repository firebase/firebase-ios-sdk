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

struct BidiActivityDetectionConfig: Encodable, Sendable {
  enum StartSensitivity: String, Encodable {
    case unspecified = "START_SENSITIVITY_UNSPECIFIED"
    case high = "START_SENSITIVITY_HIGH"
    case low = "START_SENSITIVITY_LOW"
  }

  enum EndSensitivity: String, Encodable {
    case unspecified = "END_SENSITIVITY_UNSPECIFIED"
    case high = "END_SENSITIVITY_HIGH"
    case low = "END_SENSITIVITY_LOW"
  }

  let startOfSpeechSensitivity: StartSensitivity?
  let endOfSpeechSensitivity: EndSensitivity?
  let prefixPaddingMs: Int32?
  let silenceDurationMs: Int32?
  let disabled: Bool?

  init(startOfSpeechSensitivity: StartSensitivity? = nil,
       endOfSpeechSensitivity: EndSensitivity? = nil, prefixPaddingMs: Int32? = nil,
       silenceDurationMs: Int32? = nil, disabled: Bool? = nil) {
    self.startOfSpeechSensitivity = startOfSpeechSensitivity
    self.endOfSpeechSensitivity = endOfSpeechSensitivity
    self.prefixPaddingMs = prefixPaddingMs
    self.silenceDurationMs = silenceDurationMs
    self.disabled = disabled
  }
}
