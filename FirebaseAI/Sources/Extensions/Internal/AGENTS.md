# Internal Extensions

This directory contains internal extensions to data models and other types. These extensions provide functionality that is specific to the internal workings of the Firebase AI SDK and are not part of the public API.

## Files

-   **`GenerationSchema+Gemini.swift`**: This file extends `GenerationSchema` to provide a `toGeminiJSONSchema()` method. This method transforms the schema into a format that is compatible with the Gemini backend, including renaming properties like `x-order` to `propertyOrdering`. This file is conditionally compiled and is only available when `FoundationModels` can be imported.
