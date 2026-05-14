> [!WARNING]
> **Experimental:** Using the Firebase AI SDK to build hybrid experiences on Apple platforms is an Experimental feature, which means that this feature isn't subject to any SLA or deprecation policy and could change in backwards-incompatible ways.

<br />

Gemini and Foundation models return responses as unstructured text by default.
However, some use cases require structured output. For example, you
might be using the response for other downstream tasks that require an
established data schema.

To ensure that the model's generated output always adheres to a specific schema,
you can define a data structure. You can then directly extract data from the model's output as Swift types with less post-processing.

This page describes how to generate structured output (like custom objects)
in your hybrid experiences for Apple apps.

## Before you begin

Make sure that you've completed the
[getting started guide for building hybrid experiences](get-started.md).

## Generate Structured Output via `@Generable`

Generating structured output is supported for
inference using both cloud-hosted and on-device models via the `@Generable` macro in Swift. 

The `generativeModelSession` allows you to request structured decoding via `generating: MyType.self`.

Here is an example for extracting a user profile:

```swift
import FirebaseAI
import FirebaseAILogic

@Generable
struct UserProfile {
  @Guide(description: "A unique username for the user.")
  var username: String

  @Guide(description: "A short bio about the user, no more than 100 characters.")
  var bio: String

  @Guide(description: "A list of the user's favorite topics.", .count(3))
  var favoriteTopics: [String]
}

// Ensure you have established a `generativeModelSession`
let session = firebaseAI.generativeModelSession(
    model: .hybridModel(primary: systemModel, secondary: geminiModel)
)

let prompt = "Generate a user profile for a cat lover who enjoys hiking."

// Provide `generating: UserProfile.self` to map output to your Swift type
let response = try await session.respond(to: prompt, generating: UserProfile.self)

print("Username: \(response.content.username)")
print("Bio: \(response.content.bio)")
print("Favorite Topics: \(response.content.favoriteTopics.joined(separator: ", "))")
```

The underlying system seamlessly maps your `@Generable` types to JSON schemas when querying Gemini, and handles the appropriate representation constraint when communicating with the on-device `SystemLanguageModel`.