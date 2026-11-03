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

#if compiler(>=6.4)
  // Public `@Generable` types need a `public import` of FoundationModelsFake under
  // InternalImportsByDefault, because their generated members use its types in public signatures.
  public import FoundationModelsFake

  /// A public struct, which checks that generated members repeat `public`.
  @Generable(description: "A public record")
  public struct MacroPublicRecord: Equatable {
    /// The record name.
    public var name: String

    /// The record shape.
    public var shape: MacroPublicShape

    /// The record level.
    public var level: MacroPublicLevel

    /// Optional tags.
    public var tags: [String]?
  }

  /// A public enum with associated values.
  @Generable
  public enum MacroPublicShape: Equatable {
    /// A point.
    case dot

    /// A line of the given length.
    case line(length: Int)
  }

  /// A public `String`-raw-value enum.
  @Generable
  public enum MacroPublicLevel: String, Equatable {
    /// Low.
    case low

    /// High.
    case high
  }
#endif  // compiler(>=6.4)
