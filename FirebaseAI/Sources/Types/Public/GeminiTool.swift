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

public protocol GeminiTool: Sendable, Hashable {
  var toolRepresentation: FirebaseAILogic.Tool { get }
}

public extension GeminiTool where Self == GoogleSearch {
  static func googleSearch() -> GoogleSearch {
    return GoogleSearch()
  }
}

public extension GeminiTool where Self == GoogleMaps {
  static func googleMaps() -> GoogleMaps {
    return GoogleMaps()
  }
}

public extension GeminiTool where Self == URLContext {
  static func urlContext() -> URLContext {
    return URLContext()
  }
}

public extension GeminiTool where Self == CodeExecution {
  static func codeExecution() -> CodeExecution {
    return CodeExecution()
  }
}

enum InternalGeminiTool: Sendable, Hashable {
  case googleSearch(GoogleSearch)
  case googleMaps(GoogleMaps)
  case urlContext(URLContext)
  case codeExecution(CodeExecution)
}

extension GoogleSearch: GeminiTool {
  public var toolRepresentation: FirebaseAILogic.Tool {
    return Tool.googleSearch()
  }
}

extension GoogleMaps: GeminiTool {
  public var toolRepresentation: FirebaseAILogic.Tool {
    return Tool.googleMaps()
  }
}

extension URLContext: GeminiTool {
  public var toolRepresentation: FirebaseAILogic.Tool {
    return Tool.urlContext()
  }
}

extension CodeExecution: GeminiTool {
  public var toolRepresentation: FirebaseAILogic.Tool {
    return Tool.codeExecution()
  }
}
