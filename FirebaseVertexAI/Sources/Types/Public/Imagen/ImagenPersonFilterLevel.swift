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

/// A filter level controlling whether generation of images containing people or faces is allowed.
///
/// See the
/// [`personGeneration`](https://cloud.google.com/vertex-ai/generative-ai/docs/model-reference/imagen-api#parameter_list)
/// documentation for more details.
@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public struct ImagenPersonFilterLevel: ProtoEnum {
  enum Kind: String {
    case blockAll = "dont_allow"
    case allowAdult = "allow_adult"
    case allowAll = "allow_all"
  }

  /// Disallow generation of images containing people or faces; images of people are filtered out.
  public static let blockAll = ImagenPersonFilterLevel(kind: .blockAll)

  /// Allow generation of images containing adults only; images of children are filtered out.
  ///
  /// > Important: Generation of images containing people or faces may require your use case to be
  /// reviewed and approved by Cloud support; see the [Responsible AI and usage
  /// guidelines](https://cloud.google.com/vertex-ai/generative-ai/docs/image/responsible-ai-imagen#person-face-gen)
  /// for more details.
  public static let allowAdult = ImagenPersonFilterLevel(kind: .allowAdult)

  /// Allow generation of images containing people of all ages.
  ///
  /// > Important: Generation of images containing people or faces may require your use case to be
  /// reviewed and approved; see the [Responsible AI and usage
  /// guidelines](https://cloud.google.com/vertex-ai/generative-ai/docs/image/responsible-ai-imagen#person-face-gen)
  /// for more details.
  public static let allowAll = ImagenPersonFilterLevel(kind: .allowAll)

  let rawValue: String
}
