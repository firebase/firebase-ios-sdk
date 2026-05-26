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

#if canImport(FoundationModels)
  import FoundationModels
#endif // canImport(FoundationModels)

public protocol SystemInstructionsRepresentable {
  @SystemInstructionsBuilder
  var systemInstructionsRepresentation: SystemInstructions { get }
}

extension String: SystemInstructionsRepresentable {
  public var systemInstructionsRepresentation: SystemInstructions {
    return SystemInstructions(parts: [.text(self)])
  }
}

extension Array: SystemInstructionsRepresentable where Element: SystemInstructionsRepresentable {
  public var systemInstructionsRepresentation: SystemInstructions {
    let allParts = flatMap { $0.systemInstructionsRepresentation.parts }
    return SystemInstructions(parts: allParts)
  }
}

extension FirebaseAI.GeneratedContent: SystemInstructionsRepresentable {
  public var systemInstructionsRepresentation: SystemInstructions {
    return SystemInstructions(parts: [.structure(self)])
  }
}

#if canImport(FoundationModels)
  @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  extension FoundationModels.GeneratedContent: SystemInstructionsRepresentable {
    public var systemInstructionsRepresentation: SystemInstructions {
      SystemInstructions(parts: [.structure(firebaseGeneratedContent)])
    }
  }
#endif // canImport(FoundationModels)
