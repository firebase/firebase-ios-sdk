> [!WARNING]
> **Experimental:** Using the Firebase AI SDK to build hybrid experiences on Apple platforms is an Experimental feature, which means that this feature isn't subject to any SLA or deprecation policy and could change in backwards-incompatible ways.

<br />

You can build AI-powered iOS and macOS apps and features with hybrid inference using
the Firebase AI SDK. Hybrid inference enables running inference using
on-device Apple Intelligence models when available and seamlessly falling back to
cloud-hosted models otherwise (and vice versa).

This page describes how to
[get started using the Apple client SDK](#get-started),
as well as pointing to
[additional configuration options and capabilities](configuration-options.md),
like temperature.

Note that on-device inference using `SystemLanguageModel` via Foundation Models is supported for Apple
apps running on Apple Intelligence supported devices on iOS 26.0+, macOS 26.0+, and visionOS 26.0+.

## Recommended use cases and supported capabilities

#### Recommended use cases

- Using an **on-device model for inference** offers:

  - Enhanced privacy
  - Local context
  - Inference at no-cost
  - Offline functionality
- Using **hybrid** functionality offers:

  - Reach more of your audience by accommodating on-device model availability and internet connectivity

#### Supported capabilities and features for on-device inference

On-device inference supports **multi-turn chat and single-turn text generation**,
with streaming or non-streaming output. It supports the following
text-generation capabilities:

- Generating [text from text-only input](#text-in-text-out)
- Generating structured output via the `@Generable` macro
- [Automatic function calling](function-calling.md)

Make sure to review the list of
[not-yet-available features for on-device inference](#features-not-yet-available)
at the bottom of this page.

## Before you begin

Take note of the following:

- Supported APIs:

  - In-cloud inference uses your chosen Gemini API provider.
  - On-device inference uses Apple's Foundation Models framework via `SystemLanguageModel`.
- This page describes how to **get started**.

  After completing this standard setup, check out the
  [additional configuration options and capabilities](configuration-options.md)
  (like setting temperature).

## Get started

These get started steps describe the required general setup for any supported
prompt request that you want to send.

### **Step 1**: Set up a Firebase project and connect your app to Firebase

1. Sign into the [Firebase console](https://console.firebase.google.com/),
   and then select your Firebase project.
2. In the Firebase console, go to **AI Services** \> **AI Logic**.
3. Set up your project to use a "Gemini API" provider.

### **Step 2**: Add the required SDKs

Add the `FirebaseAI` dependency to your project. This SDK provides access to both Gemini models and Apple's Foundation Models.

### **Step 3**: (Optional) Check for on-device model availability

Since hybrid inference can also use a cloud-hosted model, it is not strictly necessary to check for on-device availability before making a request. However, if you are using an "Only On-Device" configuration, or if you want to adapt your app's UI based on whether Apple Intelligence is enabled, you can check the model's availability status.

```swift
import FoundationModels

let systemModel = FirebaseAI.SystemLanguageModel.default

switch systemModel.availability {
case .available:
    print("Apple Intelligence model is ready.")
case .unavailable(.deviceNotEligible):
    print("Device does not support Apple Intelligence.")
case .unavailable(.appleIntelligenceNotEnabled):
    print("Apple Intelligence is turned off.")
case .unavailable(.modelNotReady):
    print("The model is still downloading.")
case .unavailable(let other):
    print("Model unavailable for unknown reason: \(other)")
}
```

### **Step 4**: Initialize the service and create a model session

Set up the following before you send a prompt request to the model.

1. Initialize the `FirebaseAI` service.

2. Create a `GenerativeModelSession` instance, providing a `LanguageModelProvider` that determines the hybrid behavior.

   - **Prefer On-Device**: Attempt to use the on-device `SystemLanguageModel`;
     otherwise, *fall back to the cloud-hosted Gemini model*.

```swift
import FirebaseCore
import FirebaseAI
#if canImport(FoundationModels)
import FoundationModels
#endif

// Initialize the Firebase app and Firebase AI
FirebaseApp.configure()
let firebaseAI = FirebaseAI.firebaseAI()

let systemModel = FirebaseAI.SystemLanguageModel.default
let geminiModel = firebaseAI.geminiModel(name: "gemini-2.5-flash-lite")

// Set the hybrid fallback preference: use the on-device model first, then the cloud model
let session = firebaseAI.generativeModelSession(
    model: .hybridModel(primary: systemModel, secondary: geminiModel)
)
```

### **Step 5**: Send a prompt request to a model

This section shows you how to send various types of input to generate different
types of output, including:

- [Generate text from text-only input](#text-in-text-out)

#### Generate text from text-only input

You can use `respond(to:)` to generate text from a prompt that contains text:

```swift
// Provide a prompt that contains text
let prompt = "Write a story about a magic backpack."

// To generate text output, call respond with the text input
let response = try await session.respond(to: prompt)
print(response.content)
```

Note that Firebase AI also supports streaming of text responses using
`streamResponse(to:)` (instead of `respond(to:)`).

## What else can you do?

You can use various additional configuration options and capabilities for your
hybrid experiences:

- [Set an inference mode (LanguageModelProvider fallback).](configuration-options.md#inference-modes)
- [Determine whether on-device or in-cloud inference was used.](configuration-options.md#determine-inference-mode)
- [Specify a model to use.](configuration-options.md#specify-model)
- [Use model configuration to control responses (like temperature).](configuration-options.md#model-config)
- [Generate structured output.](generate-structured-output.md)
- [Implement automatic function calling.](function-calling.md)

## Features not yet available for on-device inference

As an experimental release, not all the capabilities of cloud models are
available for *on-device* inference.

**The features listed in this section are *not yet available for on-device
inference.*** If you want to use any of these features, then we recommend configuring your session to use *only* the cloud model for a more consistent experience.

- Generating images using Gemini or Imagen models.
- Image, audio, video, and PDF document inputs (multimodal input).
- AI monitoring in the Firebase console does ***not*** show any data for
  on-device inference (including on-device logs).
