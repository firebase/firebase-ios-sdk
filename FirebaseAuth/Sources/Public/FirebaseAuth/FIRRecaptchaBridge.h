// Copyright 2024 Google LLC
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

#import <Foundation/Foundation.h>
#import <TargetConditionals.h>

#if TARGET_OS_IOS

typedef void (^FIRAuthRecaptchaTokenCallback)(NSString *_Nonnull token,
                                              NSError *_Nullable error,
                                              BOOL linked,
                                              BOOL recaptchaActionCreated);

// Provide a bridge to the Objective-C protocol provided by the optional Recaptcha Enterprise
// dependency. Once the Recaptcha Enterprise provides a Swift interop protocol, this C and
// Objective-C code can be converted to Swift. Casting to a Objective-C protocol does not seem
// possible in Swift. The C API is a workaround for linkage problems with an Objective-C API.
void FIRRecaptchaGetToken(NSString *_Nonnull siteKey,
                          NSString *_Nonnull actionString,
                          NSString *_Nonnull fakeToken,
                          _Nonnull FIRAuthRecaptchaTokenCallback callback);
#endif
