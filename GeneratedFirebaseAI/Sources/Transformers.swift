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

import Foundation

public enum Transformers {
  /// Transforms model names into the correct format for the configured backend.
  ///
  /// - Parameters:
  ///   - apiClient: The API client to use for getting configuration information.
  ///   - origin: The model name to transform; is defined as `Any?` to make usage
  ///     easier in converters, but an error will be thrown if it's undefined or not a string.
  /// - Returns: The transformed model name.
  public static func tModel(_ apiClient: APIClient, _ origin: Any?) throws -> String {
    guard let origin else {
      // TODO(daymxn): Migrate errors to some defined type to make consumption and catching cleaner.
      throw InternalError.MissingExpectedFieldInTransformer(field: "Model")
    }
    guard let model = origin as? String else {
      throw InternalError.InvalidTypeInTransformer(field: "Model", expectedType: "String")
    }

    if model.isEmpty {
      throw CommonErrors.EmptyModelName
    }

    if model.contains("..") || model.contains("?") || model.contains("&") {
      throw CommonErrors.InvalidSymbolsInModelName(name: model)
    }

    switch apiClient.backend {
    case let .vertexAI(location, publisher, projectId, _):
      if model.hasPrefix("publishers/") || model.hasPrefix("projects/")
        || model.hasPrefix("models/") {
        return model
      }
      // TODO(daymxn): This might not be correct. Needs testing on direct + firebase backends
      return "projects/\(projectId)/locations/\(location)/publishers/\(publisher)/models/\(model)"
    case let .googleAI(_, direct):
      if model.hasPrefix("models/") || model.hasPrefix("tunedModels/") {
        return model
      }
      if !direct, let projectId = apiClient.firebaseInfo?.projectID {
        return "projects/\(projectId)/models/\(model)"
      }
      return "models/\(model)"
    }
  }

  /// In other languages, this is used for supporting union types. Swift doesn't have
  /// union types, so this function is just a dummy to avoid breakage in the converters.
  public static func tContents(_ apiClient: APIClient, _ origin: Any?) throws -> Any? {
    return origin
  }

  /// Transforms an object to a valid encoded `Content` type for the backend.
  /// - Parameters:
  ///   - apiClient: The API client to use for getting configuration information.
  ///   - origin: The object to transform; can be a string, `Content`, or already encoded `Content`.
  /// - Returns: The encoded content.
  public static func tContent(_ apiClient: APIClient, _ origin: Any) throws -> NSMutableDictionary {
    if let orign = origin as? NSMutableDictionary {
      return orign
    }

    let content: Content

    if let origin = origin as? String {
      content = Content(parts: [Part(text: origin)])
    } else if let origin = origin as? Content {
      content = origin
    } else {
      throw InternalError.InvalidTypeInTransformer(
        field: "Content", expectedType: "Content | String"
      )
    }

    return try apiClient.encodeToDict(content)
  }

  /// Transforms an object to a valid encoded `Schema` type for the backend.
  public static func tSchema(_ apiClient: APIClient, _ origin: Any?) throws -> NSMutableDictionary?
  {
    guard let origin else {
      return nil
    }

    if let orign = origin as? NSMutableDictionary {
      return orign
    }

    guard let origin = origin as? Schema else {
      throw InternalError.InvalidTypeInTransformer(field: "Schema", expectedType: "Schema")
    }

    return try apiClient.encodeToDict(origin)
  }

  /// Transforms an object to a valid encoded `SpeechConfig` type for the backend.
  public static func tSpeechConfig(_ apiClient: APIClient, _ origin: Any?) throws
    -> NSMutableDictionary? {
    guard let origin else {
      return nil
    }

    if let orign = origin as? NSMutableDictionary {
      return orign
    }

    let speechConfig: SpeechConfig

    if let origin = origin as? String {
      speechConfig = SpeechConfig(
        voiceConfig: VoiceConfig(prebuiltVoiceConfig: PrebuiltVoiceConfig(voiceName: origin))
      )
    } else if let origin = origin as? SpeechConfig {
      speechConfig = origin
    } else {
      throw InternalError.InvalidTypeInTransformer(
        field: "SpeechConfig", expectedType: "SpeechConfig | String"
      )
    }

    return try apiClient.encodeToDict(speechConfig)
  }

  /// Transforms an object to a valid encoded `SpeechConfig` type for the live API.
  public static func tLiveSpeechConfig(_ apiClient: APIClient, _ origin: Any?) throws
    -> NSMutableDictionary? {
    guard let origin else {
      return nil
    }

    if let orign = origin as? NSMutableDictionary {
      return orign
    }

    let speechConfig: SpeechConfig

    if let origin = origin as? SpeechConfig {
      speechConfig = origin
    } else {
      throw InternalError.InvalidTypeInTransformer(
        field: "SpeechConfig", expectedType: "SpeechConfig"
      )
    }

    return try apiClient.encodeToDict(speechConfig)
  }

  /// In other languages, this is used for supporting union types. Swift doesn't have
  /// union types, so this function is just a dummy to avoid breakage in the converters.
  public static func tTools(_ apiClient: APIClient, _ origin: Any?) throws -> Any? {
    return origin
  }

  /// In other languages, this is used for supporting their `functions` parameter,
  /// and translating it to `functionDeclarations`. Since swift only has the `functionDeclarations`
  /// parameter, this is just a dummy function to avoid breakage in converters.
  public static func tTool<T>(_ apiClient: APIClient, _ origin: T) throws -> T {
    return origin
  }

  /// Dummy bytes transformer to avoid breakage in converters.
  public static func tBytes(_ apiClient: APIClient, _ origin: Any?) throws -> Any? {
    // wait, if it's "From" it should be `Data` but if it's `to` it should be as is, since it was
    // already
    // encoded... right?

    // So maybe we need to do if origin is data, convert to base64 encoded string, otherwise convert
    // to data

    return origin
  }

  /// Transforms an object to a cached content name for the API.
  public static func tCachedContentName(_ apiClient: APIClient, _ origin: Any?) throws -> Any? {
    guard let origin else {
      return nil
    }

    if let origin = origin as? String {
      return getResourceName(
        apiClient: apiClient, resourceName: origin, resourcePrefix: "cachedContents"
      )
    }

    throw InternalError.InvalidTypeInTransformer(
      field: "cached content name", expectedType: "String"
    )
  }

  /// Transforms an object to a list of Content for the embedding API.
  public static func tContentsForEmbed(_ apiClient: APIClient, _ origin: Any?) throws
    -> NSMutableArray? {
    guard let origin else {
      return nil
    }

    guard let orign = origin as? NSMutableArray else {
      throw InternalError.InvalidTypeInTransformer(field: "EmbedContents", expectedType: "Array")
    }

    let result = NSMutableArray()
    for content in orign {
      if apiClient.isVertexAI() {
        result.add(content)
      } else {
        guard let content = content as? NSMutableDictionary else { continue }
        guard let parts = content["parts"] as? NSMutableArray else { continue }

        for part in parts {
          guard let part = part as? NSMutableDictionary else { continue }
          guard let text = part["text"] as? String else { continue }

          result.add(text)
        }
      }
    }

    return result
  }

  /// Formats a resource name given the resource name and resource prefix.
  private static func getResourceName(apiClient: APIClient, resourceName: String,
                                      resourcePrefix: String) -> String {
    let shouldPrependCollectionIdentifier =
      (!resourceName.hasPrefix("\(resourcePrefix)/")
          && "\(resourcePrefix)/\(resourceName)".count(where: { $0 == "/" }) == 1)

    switch apiClient.backend {
    case let .vertexAI(location, _, projectId, _):
      if resourceName.hasPrefix("projects/") {
        return resourceName
      }
      if resourceName.hasPrefix("locations/") {
        return "projects/\(projectId)/\(resourceName)"
      }
      if resourceName.hasPrefix("\(resourcePrefix)/") {
        return "projects/\(projectId)/locations/\(location)/\(resourceName)"
      }
      if shouldPrependCollectionIdentifier {
        return "projects/\(projectId)/locations/\(location)/\(resourcePrefix)/\(resourceName)"
      }
      return resourceName
    case .googleAI:
      if shouldPrependCollectionIdentifier {
        return "\(resourcePrefix)/\(resourceName)"
      } else {
        return resourceName
      }
    }
  }
}
