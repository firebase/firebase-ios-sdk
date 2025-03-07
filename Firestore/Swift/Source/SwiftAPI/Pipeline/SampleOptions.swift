// Copyright 2025 Google LLC
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

public struct SampleOptions {
  let percentage: Double?
  let documents: Int?

  private init(percentage: Double?, documents: Int?) {
    self.percentage = percentage
    self.documents = documents
  }

  static func percentage(_ value: Double) -> SampleOptions {
    return SampleOptions(percentage: value, documents: nil)
  }

  static func documents(_ count: Int) -> SampleOptions {
    return SampleOptions(percentage: nil, documents: count)
  }
}
