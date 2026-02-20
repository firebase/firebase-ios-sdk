# FirebaseAI Internal Protocols

This directory contains internal protocols not meant for public consumption.
These are used for internal workings of the FirebaseAI library.
Protocols in this directory are subject to change without notice and should not be relied upon by external code.

### Files:

- **`CodableProtoEnum.swift`**: This file provides helper protocols for encoding and decoding protobuf enums. It defines `ProtoEnum` as a base protocol for types that represent a Protocol Buffer raw enum value. `DecodableProtoEnum` and `EncodableProtoEnum` provide default implementations for `Decodable` and `Encodable` respectively. `CodableProtoEnum` combines both `DecodableProtoEnum` and `EncodableProtoEnum`.
