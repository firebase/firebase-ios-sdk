// Copyright 2026 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation

@objc(FIRCLSErrorInspector)
public final class ErrorInspector: NSObject {
  override private init() {
    super.init()
  }

  /// Returns a short description of the error’s identity.
  ///
  /// The error identity is described as follows:
  ///   * **Errors conforming to `CustomNSError`**: error domain + error code
  ///   from protocol conformance (e.g. `CustomErrorDomain.123`).
  ///   * **True `NSError`s** and subclasses: `nil`
  ///   (since we only describe the identity of errors declared as Swift types).
  ///   * Errors declared as **Swift enums**: type name + case name
  ///   (e.g. `SomeErrorEnum.errorCase`); associated values are discarded.
  ///   * Errors declared as **other Swift types**: type name + error code
  ///   (e.g. `SomeErrorStruct.1`).
  @objc(getIdentityDescriptionForError:)
  public static func identityDescription(for error: any Error) -> String? {
    // Always prioritize the custom domain and code if they’re available:
    if let customNSError = error as? CustomNSError {
      return "\(type(of: customNSError).errorDomain).\(customNSError.errorCode)"
    }

    let nsError = error as NSError
    // Swift errors bridged to `NSError` have the `__SwiftNativeNSError` underlying type:
    guard NSStringFromClass(type(of: nsError)).contains("SwiftNative") else {
      // This is a true `NSError` (or its subclass), not a Swift error bridged to one.
      // We only report the identity of errors declared as Swift types.
      // See https://github.com/firebase/firebase-ios-sdk/pull/16045
      return nil
    }

    // This is a Swift error bridged to `NSError`.
    let typeLabel = String(describing: type(of: error))
    let mirror = Mirror(reflecting: error)

    guard mirror.displayStyle == .enum else {
      // This error is not declared as an enum. We fall back onto the `NSError` bridge.
      // `typeLabel` is used instead of `nsError.domain` for consistency
      // (we only want the type name, not its parent types or module).
      return "\(typeLabel).\(nsError.code)"
    }

    // The error is declared as an enum; we need to extract the case name.
    if let caseLabel = mirror.children.first?.label {
      // This enum case has an associated value. We don’t want it to affect the error’s identity:
      // `someError(123)` and `someError(456)` should produce the same result `someError`.
      // For enum cases with associated values, the bare case name is stored as the first child.
      return "\(typeLabel).\(caseLabel)"
    } else {
      // For enum cases with no associated values, the `Mirror.children` array is empty;
      // the case name can be retrieved using the synthesized `CustomStringConvertible` conformance.
      return "\(typeLabel).\(error)"
    }
  }
}
