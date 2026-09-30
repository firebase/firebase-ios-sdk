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

// MARK: - OrcaRouter Wiring

/// Wires a resolved ``OrcaRouterProvider`` into the transport the SDK already uses.
///
/// This is the bridge that makes OrcaRouter a first-class backend rather than a special case
/// bolted onto one code path. Everything downstream — Foundation Models, the Gemini API surface,
/// model discovery — composes the same ``EndpointConfiguration`` and ``HeaderProvider`` values the
/// SDK produces for its built-in backends, so the two authentication entries still collapse into a
/// single credential and a single transport.
extension OrcaRouterProvider {
  /// The ``EndpointConfiguration`` for this provider's inference origin.
  ///
  /// The existing client composes URLs as `{scheme}://{host}[:{port}]/{apiVersion}/{resource}`,
  /// which is exactly what `https://api.orcarouter.ai/v1/...` is.
  package var endpointConfigurationForTransport: EndpointConfiguration {
    apiEndpointConfiguration
  }

  /// A ``ModelResource`` for an OrcaRouter model identifier.
  ///
  /// OrcaRouter keeps its `vendor/model` namespace verbatim in the payload. It is not a
  /// resource-oriented API, so there is no `models/…` or `publishers/…` prefix to add.
  ///
  /// - Parameter modelID: The identifier exactly as the live catalog returned it.
  package func modelResource(forModelIdentifier modelID: String) -> ModelResource {
    ModelResource(
      modelID: modelID,
      urlResourceName: modelID,
      payloadResourceName: modelID
    )
  }

  /// A dynamic authorization header for the inference origin.
  ///
  /// The credential is read per request from ``OrcaRouterCredentialSource``, so a key the user
  /// pastes later, or a reauthorization that replaces a rejected one, takes effect without
  /// rebuilding the client. The key is placed in the `Authorization` header and nowhere else.
  ///
  /// - Parameter credentialSource: The adapter that supplies the credential.
  package func headerProvider(
    credentialSource: any OrcaRouterCredentialSource
  ) -> HeaderProvider {
    HeaderProvider {
      let credential = try await credentialSource.acquire()
      return ["Authorization": "Bearer \(credential.apiKey)"]
    }
  }
}
