/*
 * Copyright 2026 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

// NOT PUBLIC API: this conformance is for use by Firebase SDKs only, and may change at any time.
//
// `FIRAppCheck` is declared in `FIRAppCheck.h` and implemented in Swift with `@objc
// @implementation`, which can only implement protocol conformances declared in an Objective-C
// header.
// - SwiftPM and binary distributions (`zip-builder`, `ReleaseTooling`): exposed only through the
//   explicit submodule `FirebaseAppCheck.Internal`, not `FirebaseAppCheck.h`.
// - CocoaPods (internal testing only): included in the pod's generated umbrella header so both
//   framework and `--use-modular-headers` static-library builds see the conformance.

#import <Foundation/Foundation.h>

#import <FirebaseAppCheckInterop/FirebaseAppCheckInterop.h>

#import <FirebaseAppCheck/FIRAppCheck.h>

NS_ASSUME_NONNULL_BEGIN

/// Other Firebase SDKs get App Check tokens through `FIRAppCheckInterop`.
@interface FIRAppCheck () <FIRAppCheckInterop>
@end

NS_ASSUME_NONNULL_END
