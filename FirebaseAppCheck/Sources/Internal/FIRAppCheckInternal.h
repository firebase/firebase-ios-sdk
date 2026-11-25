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

// NOT PUBLIC API: these declarations are for use by the Firebase App Check SDK only, and may
// change or be removed at any time.
//
// The classes of the SDK are declared in Objective-C headers and implemented in Swift with
// `@objc @implementation` extensions, which can only implement members declared in a header. This
// header declares the members that the SDK uses internally. It is not imported by
// `FirebaseAppCheck.h`:
// - SwiftPM: it's only in the explicit submodule `FirebaseAppCheck.Internal`.
// - CocoaPods and the binary distributions built from the podspec: it's a public header of the
//   pod, so the generated umbrella header imports it, and apps can see these declarations.

#import <Foundation/Foundation.h>

#import <FirebaseAppCheckInterop/FirebaseAppCheckInterop.h>

#import "FIRAppCheck.h"
#import "FIRRecaptchaProvider.h"

@class FIRApp;

NS_ASSUME_NONNULL_BEGIN

/// Other Firebase SDKs get App Check tokens through `FIRAppCheckInterop`.
@interface FIRAppCheck () <FIRAppCheckInterop>

/// Creates the App Check instance of a Firebase app. Use `+[FIRAppCheck appCheckWithApp:]`.
- (nullable instancetype)initWithApp:(FIRApp *)app;

@end

API_AVAILABLE(ios(15.0), visionos(1.0))
API_UNAVAILABLE(macos, tvos, watchos, macCatalyst)
@interface FIRRecaptchaProvider ()

/// Creates a provider that wraps an App Check Core provider. For tests.
/// @param recaptchaProvider A `GACAppCheckProvider` (`AppCheckCoreProvider` in Swift).
/// @return `nil` if `recaptchaProvider` isn't a `GACAppCheckProvider`.
- (nullable instancetype)initWithRecaptchaProvider:(id)recaptchaProvider;

@end

NS_ASSUME_NONNULL_END
