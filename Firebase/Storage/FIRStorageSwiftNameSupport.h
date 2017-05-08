/*
 * Copyright 2017 Google
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

#ifndef FIR_SWIFT_NAME

#import <Foundation/Foundation.h>

// NS_SWIFT_NAME can only translate factory methods before the iOS 9.3 SDK.
// // Wrap it in our own macro if it's a non-compatible SDK.
#ifdef __IPHONE_9_3
#define FIR_SWIFT_NAME(X) NS_SWIFT_NAME(X)
#else
#define FIR_SWIFT_NAME(X)  // Intentionally blank.
#endif  // #ifdef __IPHONE_9_3

#endif  // FIR_SWIFT_NAME