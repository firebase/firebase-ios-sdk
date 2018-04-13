// Copyright 2017 Google
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

NS_ASSUME_NONNULL_BEGIN

/** Helper for creating a general exception for invalid usage of an API. */
NSException *FUNInvalidUsage(NSString *exceptionName, NSString *format, ...);

/**
 * Macro to throw exceptions in response to API usage errors. Avoids the lint warning you usually
 * get when using @throw and (unlike a function) doesn't trigger warnings about not all codepaths
 * returning a value.
 *
 * Exceptions should only be used for programmer errors made by consumers of the SDK, e.g.
 * invalid method arguments.
 *
 * For recoverable runtime errors, use NSError**.
 * For internal programming errors, use FSTFail().
 */
#define FUNThrowInvalidArgument(format, ...)                                       \
  do {                                                                             \
    @throw FUNInvalidUsage(@"FIRInvalidArgumentException", format, ##__VA_ARGS__); \
  } while (0)

NS_ASSUME_NONNULL_END
