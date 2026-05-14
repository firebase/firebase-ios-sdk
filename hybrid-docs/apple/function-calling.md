> [!WARNING]
> **Experimental:** Using the Firebase AI SDK to build hybrid experiences on Apple platforms is an Experimental feature, which means that this feature isn't subject to any SLA or deprecation policy and could change in backwards-incompatible ways.

<br />

Generative models are powerful at solving many types of problems. However, they
are constrained by limitations like:

- They are frozen after training, leading to stale knowledge.
- They can't query or modify external data.

Function calling can help you overcome some of these limitations.
Function calling is sometimes referred to as *tool use* because it allows a
model to use external tools such as APIs and functions to generate its final
response.

This page describes how to implement automatic function calling in your hybrid experiences for Apple apps using `FoundationModels.Tool`.

## Before you begin

Make sure that you've completed the
[getting started guide for building hybrid experiences](get-started.md).

## Automatic Function Calling via `FoundationModels.Tool`

On Apple platforms running iOS 26+, macOS 26+, or visionOS 26+, you can define tools using the `FoundationModels.Tool` protocol. The Firebase AI SDK will automatically manage the back-and-forth communication required to invoke these tools and pass the results back to the model, streamlining the function calling process.

### Step 1: Define the Tool

First, define your tool by conforming to the `FoundationModels.Tool` protocol. You can use the `@Generable` macro to easily define the expected arguments and return types.

```swift
import FirebaseAI
import FirebaseAILogic
import FoundationModels

@available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
struct GetTemperatureTool: FoundationModels.Tool {
  let description = "Returns the current temperature for the specified location."

  @Generable
  struct Location {
    let city: String
    @Guide(description: "The province or state.")
    let region: String
    let country: String
  }

  @Generable
  struct Temperature {
    @Generable enum Units { case celsius, fahrenheit, kelvin }

    let temperature: Double
    let units: Units
  }

  // The call method is automatically invoked by the SDK when the model requests it
  func call(arguments: Location) async throws -> Temperature {
    // TODO(developer): Make a network request to an actual weather API here
    
    // For demo purposes, we return a hardcoded temperature
    return Temperature(temperature: 25.0, units: .celsius)
  }
}
```

### Step 2: Provide the Tool to the Model Session

When initializing your `GenerativeModelSession`, pass an instance of your tool in the `tools` array. The tool can be used by both the on-device `SystemLanguageModel` and cloud-hosted `GeminiModel`.

```swift
// Using this SDK to access on-device inference requires iOS 26+ / macOS 26+
if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
    let systemModel = FirebaseAI.SystemLanguageModel.default
    let geminiModel = firebaseAI.geminiModel(name: "gemini-2.5-flash-lite")
    
    // Initialize the tool
    let temperatureTool = GetTemperatureTool()
    
    // Set the hybrid fallback preference and provide the tools
    let session = firebaseAI.generativeModelSession(
        model: .hybridModel(primary: systemModel, secondary: geminiModel),
        tools: [temperatureTool],
        instructions: """
        You are a weather bot that specializes in reporting outdoor temperatures in Celsius.
        Always use the `GetTemperatureTool` function to determine the current temperature in a location.
        """
    )
}
```

### Step 3: Send a Prompt

Now you can send a standard text prompt to the session. If the model determines it needs to call your tool, it will automatically pause generation, execute your `call(arguments:)` method, incorporate the result into its context, and resume generating the final response.

```swift
let prompt = "What is the current temperature in Waterloo, Ontario, Canada?"

// The SDK automatically handles calling the tool and returning the final natural language response
let response = try await session.respond(to: prompt)

print(response.content)
// Output example: 
// The current temperature in Waterloo, Ontario, Canada is 25°C.
```
