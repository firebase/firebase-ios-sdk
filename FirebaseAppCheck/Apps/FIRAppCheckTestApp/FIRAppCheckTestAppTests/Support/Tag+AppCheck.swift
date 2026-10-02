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

#if canImport(Testing)
  import Testing

  extension Tag {
    /// Indicates that a test is an end-to-end integration test.
    @Tag static var integration: Self

    /// Verifies that state written by App Check v11 remains readable by v12.
    ///
    /// A failure in this category means shipped users lose cached tokens or
    /// re-attest unnecessarily on upgrade.
    @Tag static var migration: Self

    /// Exercises the App Attest provider. Requires physical hardware with a
    /// Secure Enclave; unsupported in the Simulator.
    @Tag static var appAttest: Self

    /// Exercises the DeviceCheck provider. Requires physical hardware and a
    /// DeviceCheck private key registered with the App Check backend.
    @Tag static var deviceCheck: Self

    /// Exercises the debug provider, which runs in the Simulator.
    @Tag static var debugProvider: Self

    /// Exercises request coalescing, actor isolation, or multi-threaded access.
    @Tag static var concurrency: Self

    /// Exercises the Swift/Objective-C boundary: bridged types, error domains,
    /// and the queue a callback is delivered on.
    @Tag static var interop: Self

    /// Exercises the reCAPTCHA Enterprise provider.
    @Tag static var recaptcha: Self
  }
#endif // canImport(Testing)
