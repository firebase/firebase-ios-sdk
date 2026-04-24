# Use model configuration to control responses

In each call to a model, you can send along a model configuration to control how
the model generates a response. Each model offers different configuration
options.
You can also experiment with prompts and model configurations using [Google AI Studio](https://aistudio.google.com).

## Configure Gemini models

This section shows you how to
[set up a configuration](https://firebase.google.com/docs/ai-logic/model-parameters#config-gemini) for use with
Gemini models and provides a
[description of each parameter](https://firebase.google.com/docs/ai-logic/model-parameters#parameters-descriptions-gemini).

### Set up a model configuration (Gemini)

#### Config for general Gemini use cases

You can specify the configuration by passing a `GenerationConfig` instance to the `respond` or `streamResponse` methods.

### Swift

Set the values of the parameters in a
[`GenerationConfig`](https://firebase.google.com/docs/reference/swift/firebaseailogic/api/reference/Structs/GenerationConfig)
and pass it to the `respond` or `streamResponse` methods.

```swift
import FirebaseAILogic

// Set parameter values in a `GenerationConfig`.
// IMPORTANT: Example values shown here. Make sure to update for your use case.
let config = GenerationConfig(
  candidateCount: 1,
  temperature: 0.9,
  topP: 0.1,
  topK: 16,
  maxOutputTokens: 200,
  stopSequences: ["red"]
)

// Start a session with the model.
let session = FirebaseAI.firebaseAI(backend: .googleAI()).generativeModelSession(model: "GEMINI_MODEL_NAME")

// Pass the configuration options to the respond method.
let response = try await session.respond(to: "Hello!", options: config)

// ...
```



## Configure Hybrid and System models

When using hybrid (on-device and cloud) or system-only models, you can set configuration options for both Foundation Models and Gemini in the same call using the static methods in `ResponseGenerationOptions`.

### Swift

Use `.hybrid(gemini:foundationModels:)` to combine configurations.

```swift
import FirebaseAILogic

// Create configurations for each model
let geminiConfig = GenerationConfig(temperature: 0.9)
let fmOptions = FirebaseAI.GenerationOptions(maxTokens: 100)

// Combine them using the static method
let options = ResponseGenerationOptions.hybrid(gemini: geminiConfig, foundationModels: fmOptions)

// Start a hybrid session (e.g., fallback from on-device to cloud)
let session = FirebaseAI.firebaseAI(backend: .googleAI()).generativeModelSession(
  model: .hybridModel(primary: .systemModel(), secondary: "gemini-2.5-flash")
)

// Pass the combined options to the respond or streamResponse method
let response = try await session.respond(to: "Hello!", options: options)
```

## Configure Foundation Models

When using the on-device `SystemLanguageModel` provided by the Apple Foundation Models framework, you can set specific configuration options using `FirebaseAI.GenerationOptions`.

### Swift

Use `FirebaseAI.GenerationOptions` to set parameters like `sampling`, `temperature`, and `maximumResponseTokens`.

```swift
import FirebaseAILogic

// Set parameter values in a `GenerationOptions`.
let options = FirebaseAI.GenerationOptions(
  sampling: .random(top: 40, seed: 42),
  temperature: 0.7,
  maximumResponseTokens: 150
)

// Start a session with the system model.
let session = FirebaseAI.firebaseAI(backend: .googleAI()).generativeModelSession(model: .systemModel())

// Pass the configuration options to the respond method.
let response = try await session.respond(to: "Explain quantum computing in simple terms.", options: options)

// ...
```

### Description of parameters

Here is a high-level overview of the available parameters, as applicable.

You can find a
[comprehensive list of parameters and their values](https://ai.google.dev/api/generate-content#generationconfig)
in the Gemini Developer API documentation.


| Parameter | Description | Default value |
|---|---|---|
| Candidate count `candidateCount` | Specifies the number of response variations to return. For each request, you're charged for the output tokens of all candidates, but you're only charged once for the input tokens. Supported values: `1` - `8` (inclusive) *Only applicable when using `generateContent` and the latest Gemini models. The Live API models and `generateContentStream` are not supported.* | `1` |
| Frequency penalty `frequencyPenalty` | Controls the probability of including tokens that repeatedly appear in the generated response. Positive values penalize tokens that repeatedly appear in the generated content, decreasing the probability of repeating content. | --- |
| Max output tokens `maxOutputTokens` | Specifies the maximum number of tokens that can be generated in the response. | --- |
| Presence penalty `presencePenalty` | Controls the probability of including tokens that already appear in the generated response. Positive values penalize tokens that already appear in the generated content, increasing the probability of generating more diverse content. | --- |
| Stop sequences `stopSequences` | Specifies a list of strings that tells the model to stop generating content if one of the strings is encountered in the response. | --- |
| Temperature `temperature` | Controls the degree of randomness in the response. Lower temperatures result in more deterministic responses, and higher temperatures result in more diverse or creative responses. | Depends on the model |
| Top-K `topK` | Limits the number of highest probability words used in the generated content. A top-K value of `1` means the next selected token should be *the most probable* among all tokens in the model's vocabulary, while a top-K value of `n` means that the next token should be selected from among *the *n* most probable* tokens (all based on the temperature that's set). | Depends on the model |
| Top-P `topP` | Controls diversity of generated content. Tokens are selected from the most probable (see top-K above) to least probable until the sum of their probabilities equals the top-P value. | Depends on the model |
| Response modality `responseModality` | Specifies the type of streamed output when using the Live API or native multimodal output by a Gemini model, for example text, audio, or images. *Only applicable when using the Live API models, or when using a Gemini model capable of multimodal output.* | --- |
| Speech (voice) `speechConfig` | Specifies the voice used for the streamed audio output when using the Live API. *Only applicable when using the Live API models.* | `Puck` |

> [!NOTE]
> **Note** : The following two configurations are also supported in the `GenerationConfig`:
>
> - [Generating structured output (like JSON)](https://firebase.google.com/docs/ai-logic/generate-structured-output) is controlled by using the `responseMimeType` and `responseSchema` parameters.
> - [Specifying a thinking-related configuration](https://firebase.google.com/docs/ai-logic/thinking) (like a *thinking budget* and whether to include *thought summaries* ) is controlled by using the `thinkingConfig` (only applicable for Gemini 3 and Gemini 2.5 models).

### Description of parameters (Foundation Models)

Here is an overview of the parameters available when using the on-device `SystemLanguageModel` provided by Apple's Foundation Models framework.

| Parameter | Description | Default value |
|---|---|---|
| Sampling mode `sampling` | Controls how tokens are selected from the probability distribution. Supports `greedy` (always chooses the most likely token), `random(top:seed:)` (Top-K), and `random(probabilityThreshold:seed:)` (Top-P/Nucleus). | System default |
| Temperature `temperature` | Influences the confidence and randomness of the model's response. Value must be between `0` and `1` inclusive. Low temperatures result in more stable and predictable responses, while high temperatures give the model more creative license. | System default |
| Max response tokens `maximumResponseTokens` | The maximum number of tokens the model is allowed to produce in its response. Used to protect against unexpectedly verbose responses. | Longest answer supported by context size |
