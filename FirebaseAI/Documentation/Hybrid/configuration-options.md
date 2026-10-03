> [!WARNING]
> **Experimental:** Using the Firebase AI SDK to build hybrid experiences on Apple platforms is an Experimental feature, which means that this feature isn't subject to any SLA or deprecation policy and could change in backwards-incompatible ways.

<br />

This page describes the following configuration options for hybrid experiences on Apple platforms:

- [Set an inference mode (Model Provider preference).](#inference-modes)

- [Determine whether on-device or in-cloud inference was used.](#determine-inference-mode)

- [Specify a model to use.](#specify-model)

- [Use model configuration to control responses (like temperature).](#model-config)

**Make sure that you've completed the
[getting started guide for building hybrid experiences](get-started.md).**

## Set an inference mode

On Apple platforms, the hybrid inference behavior is controlled by how you configure the `LanguageModelProvider` when you initialize your `GenerativeModelSession`. Instead of relying on a dedicated inference mode enum, you instantiate the models and combine them using `.hybridModel(primary:secondary:)` to establish fallback priorities.

Here are the equivalent patterns for the available inference behaviors:

- **Prefer On-Device** : Attempt to use the on-device model if it's available. Otherwise, automatically *fall back to the cloud-hosted model*.

```swift
let systemModel = FirebaseAI.SystemLanguageModel.default
let geminiModel = firebaseAI.geminiModel(name: "gemini-2.5-flash-lite")
let session = firebaseAI.generativeModelSession(
    model: .hybridModel(primary: systemModel, secondary: geminiModel)
)
```

- **Only On-Device** : Attempt to use the on-device model if it's available. Otherwise, *throw an error*.

```swift
let systemModel = FirebaseAI.SystemLanguageModel.default
let session = firebaseAI.generativeModelSession(model: systemModel)
```

- **Prefer In-Cloud** : Attempt to use the cloud-hosted model. If it fails (e.g. due to lack of network connection), *fall back to the on-device model*.

```swift
let systemModel = FirebaseAI.SystemLanguageModel.default
let geminiModel = firebaseAI.geminiModel(name: "gemini-2.5-flash-lite")
let session = firebaseAI.generativeModelSession(
    model: .hybridModel(primary: geminiModel, secondary: systemModel)
)
```

- **Only In-Cloud** : Attempt to use the cloud-hosted model. Otherwise, *throw an error*.

```swift
let geminiModel = firebaseAI.geminiModel(name: "gemini-2.5-flash-lite")
let session = firebaseAI.generativeModelSession(model: geminiModel)
```

## Determine whether on-device or in-cloud inference was used

If your hybrid strategy relies on a fallback (like Prefer On-Device or Prefer In-Cloud), it might
be helpful to know which model ultimately served the request. This information is
provided by the `rawResponse.modelVersion` property of the response.

You can inspect the `modelVersion` and match it to your model instances to verify the source:

```swift
let response = try await session.respond(to: prompt)

if response.rawResponse.modelVersion == systemModel._modelName {
    print("Inference was executed on-device.")
} else {
    print("Inference was executed in the cloud via Gemini.")
}

print(response.content)
```

## Specify a model to use

You can specify a model to use when you declare your `SystemLanguageModel` (for on-device) or `GeminiModel` (for cloud) instances.

- **Specify a cloud-hosted model**:
  - Provide the model name string to `firebaseAI.geminiModel(name:)`.
  - Find model names for all [supported cloud-hosted Gemini models](https://firebase.google.com/docs/ai-logic/models).

- **Specify an on-device model**:
  - The on-device `SystemLanguageModel` is automatically selected and managed by Apple's Foundation Models framework.
  - You can influence the type of tasks it excels at by specifying a `UseCase` and safety `Guardrails` during initialization:

```swift
// Example of a specialized on-device model configuration
let customSystemModel = FirebaseAI.SystemLanguageModel(
    useCase: .general, 
    guardrails: .default
)
```

## Use model configuration to control responses

In each request to a model, you can send along model configurations to control
how the model generates a response. Cloud-hosted models and on-device models
offer different configuration options.

When making a request using `.respond(to:options:)`, you can specify options using the `ResponseGenerationOptions.hybrid()` factory, allowing you to pass independent options for both Gemini and Foundation Models at the same time:

```swift
import FoundationModels

// Options for the cloud-hosted Gemini model
let geminiConfig = GenerationConfig(temperature: 0.8, topK: 10)

// Options for the on-device Apple Foundation model
let systemOptions = FirebaseAI.GenerationOptions(sampling: .greedy, temperature: 0.8)

let response = try await session.respond(
    to: prompt,
    options: .hybrid(
        gemini: geminiConfig, 
        foundationModels: systemOptions
    )
)
```