# FirebaseAI Internal Tool-related Types

This directory contains internal data types related to tools and function calling.
These types are used to provide context to tools that can be executed by the model.
These types are internal and subject to change.

### Files:

- **`URLContext.swift`**: Defines the `URLContext` struct. It is currently an empty struct that serves to enable the URL context tool. Its presence in a `Tool` enables the feature, and it may be expanded in the future to carry more specific context.
