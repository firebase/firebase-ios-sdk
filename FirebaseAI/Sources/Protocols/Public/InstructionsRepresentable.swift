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

public extension FirebaseAI {
  protocol InstructionsRepresentable {
    @FirebaseAI.InstructionsBuilder
    var firebaseInstructionsRepresentation: FirebaseAI.Instructions { get }
  }
}

extension String: FirebaseAI.InstructionsRepresentable {
  public var firebaseInstructionsRepresentation: FirebaseAI.Instructions {
    return FirebaseAI.Instructions(parts: [.text(self)])
  }
}

extension Array: FirebaseAI.InstructionsRepresentable
  where Element: FirebaseAI.InstructionsRepresentable {
  public var firebaseInstructionsRepresentation: FirebaseAI.Instructions {
    let allParts = flatMap { $0.firebaseInstructionsRepresentation.parts }
    return FirebaseAI.Instructions(parts: allParts)
  }
}

extension FirebaseAI.GeneratedContent: FirebaseAI.InstructionsRepresentable {
  public var firebaseInstructionsRepresentation: FirebaseAI.Instructions {
    return FirebaseAI.Instructions(parts: [.structure(self)])
  }
}

#if canImport(FoundationModels)
  @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
  @available(tvOS, unavailable)
  @available(watchOS, unavailable)
  extension FoundationModels.GeneratedContent: FirebaseAI.InstructionsRepresentable {
    public var firebaseInstructionsRepresentation: FirebaseAI.Instructions {
      FirebaseAI.Instructions(parts: [.structure(firebaseGeneratedContent)])
    }
  }
#endif // canImport(FoundationModels)
