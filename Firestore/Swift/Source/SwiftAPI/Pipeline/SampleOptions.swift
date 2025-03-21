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

public struct SampleOption {
  let percentage: Double?
  let count: Int64?

  private init(percentage: Double?, count: Int64?) {
    self.percentage = percentage
    self.count = count
  }

  public init(percentage: Double) {
    self.init(percentage: percentage, count: nil)
  }

  public init(count: Int64) {
    self.init(percentage: nil, count: count)
  }
}
