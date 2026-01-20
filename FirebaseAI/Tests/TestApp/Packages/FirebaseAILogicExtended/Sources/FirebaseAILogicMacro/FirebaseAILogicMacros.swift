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

@_exported import FirebaseAILogic

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
@attached(extension, conformances: FirebaseGenerable, names: named(init(_:)), named(modelOutput))
@attached(member, names: arbitrary) public macro FirebaseGenerable(description: String? = nil) =
  #externalMacro(
    module: "FirebaseAILogicMacros",
    type: "FirebaseGenerableMacro"
  )

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
@attached(peer) public macro FirebaseGuide<T>(description: String? = nil,
                                              _ guides: FirebaseGenerationGuide<T>...) =
  #externalMacro(
    module: "FirebaseAILogicMacros",
    type: "FirebaseGuideMacro"
  ) where T: FirebaseGenerable

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
@attached(peer) public macro FirebaseGuide(description: String) =
  #externalMacro(
    module: "FirebaseAILogicMacros",
    type: "FirebaseGuideMacro"
  )
