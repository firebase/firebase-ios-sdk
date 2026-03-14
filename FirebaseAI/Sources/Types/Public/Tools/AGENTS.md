# FirebaseAI Public Tool-related Types

This directory contains public data types related to tools and function calling.
These types are used by developers to define and configure tools that the model can execute.

### Files

- **`GoogleMaps.swift`**: Defines the `GoogleMaps` struct, which is a tool that allows the model to ground its responses in data from Google Maps. It also defines the `GoogleMapsGroundingChunk` struct, which represents a grounding chunk sourced from Google Maps.
- **`CodeExecution.swift`**: Defines the `CodeExecution` struct, which is a tool that allows the model to execute code. This can be used to solve complex problems by leveraging the model's ability to generate and execute code. It is currently an empty struct, but its presence in a `Tool` enables the code execution feature.
