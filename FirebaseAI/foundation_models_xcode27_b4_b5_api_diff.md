# 🧰 FoundationModels API Diff

**Versions:** Xcode 27 Beta 4 ➡️ Xcode 27 Beta 5

Below is a summary of the public interface changes in the `FoundationModels` framework between Xcode 27 Beta 4 (27A5228h) and Beta 5 (27A5237l).

## 🚨 Removed Declarations

These following items have been completely removed from the public API.

* **Constructors:**

  * `LanguageModelCapabilities.init(capabilities:)`

* **Protocols:**

  * `Transcript.CustomSegment`

* **Enums/Cases:**

  * `Transcript.Segment.custom`

* **Functions:**

  * `LanguageModelExecutorGenerationChannel.Response.Action.updateCustomSegment(_:)`

## 🏷️ Renamed Declarations

* `ImageReference.resolve(in:)` has been renamed to **`ImageReference.resolved(in:)`**

## 🔄 Type & Signature Changes

### 1. The `GeneratedContent` Metadata Migration

Across the framework, untyped metadata dictionaries have been updated to use strictly typed structures.

* **Properties** have changed from `[String : any Sendable & Codable & Equatable]` to **`[String : GeneratedContent]`**.

* **Parameters/Constructors** have changed to accept **`[String : any ConvertibleToGeneratedContent]`**.

**Affected Properties (Type changed to `[String : GeneratedContent]`):**

* `LanguageModelExecutorGenerationChannel.Metadata.values`

* `LanguageModelExecutorGenerationChannel.Usage.metadata`

* `LanguageModelExecutorGenerationRequest.metadata`

* `LanguageModelSession.Usage.metadata`

* `Transcript.Prompt.metadata`

* `Transcript.Reasoning.metadata`

* `Transcript.Response.metadata`

* `Transcript.ToolCall.metadata`

**Affected Methods & Initializers (Parameters updated to `ConvertibleToGeneratedContent`):**

* `LanguageModelExecutorGenerationChannel.Reasoning.Action.updateMetadata(_:)`

* `LanguageModelExecutorGenerationChannel.Reasoning.Action.updateUsage(...)`

* `LanguageModelExecutorGenerationChannel.Response.Action.updateMetadata(_:)`

* `LanguageModelExecutorGenerationChannel.Response.Action.updateUsage(...)`

* `LanguageModelExecutorGenerationChannel.ToolCalls.Action.updateMetadata(_:)`

* `LanguageModelExecutorGenerationChannel.ToolCalls.Action.updateUsage(...)`

* `LanguageModelExecutorGenerationChannel.ToolCalls.ToolCall.Action.updateMetadata(_:)`

* `LanguageModelExecutorGenerationChannel.Usage.init(...)`

* `LanguageModelExecutorGenerationRequest.init(...)`

* `LanguageModelSession.Usage.init(...)`

* All overloads of `LanguageModelSession.respond(...)` *(metadata parameter)*

* All overloads of `LanguageModelSession.streamResponse(...)` *(metadata parameter)*

* `Transcript.Prompt.init(...)`

* `Transcript.Reasoning.init(...)`

* `Transcript.Response.init(...)`

* `Transcript.ToolCall.init(...)`

### 2. Transcript History Type Change

History collections are no longer exposed as raw array slices. They now use a dedicated `HistoryView` type.

* **Old Type:** `ArraySlice<FoundationModels.Transcript.Entry>`

* **New Type:** `FoundationModels.Transcript.HistoryView`

**Affected Properties:**

* `SessionPropertyValues.history`

* `Transcript.history`

### 3. Other Type Changes

* **`ImageReference.resolved(in:)`** (formerly `resolve(in:)`)

  * **Parameter `in`** changed from `FoundationModels.Transcript` to `some Sequence<FoundationModels.Transcript.Entry>`.

## ⚙️ Concurrency & Attribute Changes

Changes to throwing behaviors and actor isolation.

* **`PrivateCloudComputeLanguageModel.supportsLocale(_:)`**

  * Added `throws`

  * Added `@nonisolated`

* **`PrivateCloudComputeLanguageModel.supportedLanguages`**

  * Added `@nonisolated`

## 💡 Migrating Away from CustomSegment

With the removal of `Transcript.CustomSegment` and the `.custom` segment case in Beta 5, you can no longer inject arbitrary Swift types directly into the language model's transcript tree. The framework now enforces a stricter separation of concerns.

Depending on your use case, here are the alternatives provided by the new `Transcript.Segment` enum:

### 1. For Structured Data: `StructuredSegment`

If you used custom segments to pass application-specific metadata or model objects into the transcript, you should now use `Transcript.Segment.structure`.

* You can encapsulate your data within a `Transcript.StructuredSegment`.

* The payload must be converted to the newly introduced `GeneratedContent` type (by making your models conform to `Generable` or `ConvertibleToGeneratedContent`).

* You can use the `schemaName` property to identify the type of data being passed.

### 2. For Media and Files: `AttachmentSegment`

If you used custom segments to insert media (like images) into the context window, Beta 5 introduces a formal `Transcript.Segment.attachment`.

* Wrap your media in a `Transcript.AttachmentSegment`.

* Currently, the `Transcript.Attachment` enum only supports images via `.image(ImageAttachment)`, which accepts `CGImage`, `CIImage`, `CVPixelBuffer`, or file URLs.
