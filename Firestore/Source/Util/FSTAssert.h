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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// Fails the current Objective-C method if the given condition is false.
//
// Unlike NSAssert, this macro is never compiled out if assertions are disabled.
#define FSTAssert(condition, format, ...) \
  do {                                    \
    if (!(condition)) {                   \
      FSTFail((format), ##__VA_ARGS__);   \
    }                                     \
  } while (0)

// Fails the current C function if the given condition is false.
//
// Unlike NSCAssert, this macro is never compiled out if assertions are disabled.
#define FSTCAssert(condition, format, ...) \
  do {                                     \
    if (!(condition)) {                    \
      FSTCFail((format), ##__VA_ARGS__);   \
    }                                      \
  } while (0)

// Unconditionally fails the current Objective-C method.
//
// This macro fails by calling [[NSAssertionHandler currentHandler] handleFailureInMethod]. It
// also calls abort(3) in order to make this macro appear to never return, even though the call
// to handleFailureInMethod itself never returns.
#define FSTFail(format, ...)                                                             \
  do {                                                                                   \
    NSString *_file = [NSString stringWithUTF8String:__FILE__];                          \
    NSString *_description = [NSString stringWithFormat:(format), ##__VA_ARGS__];        \
    [[NSAssertionHandler currentHandler]                                                 \
        handleFailureInMethod:_cmd                                                       \
                       object:self                                                       \
                         file:_file                                                      \
                   lineNumber:__LINE__                                                   \
                  description:@"FIRESTORE INTERNAL ASSERTION FAILED: %@", _description]; \
    abort();                                                                             \
  } while (0)

// Unconditionally fails the current C function.
//
// This macro fails by calling [[NSAssertionHandler currentHandler] handleFailureInFunction]. It
// also calls abort(3) in order to make this macro appear to never return, even though the call
// to handleFailureInFunction itself never returns.
#define FSTCFail(format, ...)                                                              \
  do {                                                                                     \
    NSString *_file = [NSString stringWithUTF8String:__FILE__];                            \
    NSString *_function = [NSString stringWithUTF8String:__PRETTY_FUNCTION__];             \
    NSString *_description = [NSString stringWithFormat:(format), ##__VA_ARGS__];          \
    [[NSAssertionHandler currentHandler]                                                   \
        handleFailureInFunction:_function                                                  \
                           file:_file                                                      \
                     lineNumber:__LINE__                                                   \
                    description:@"FIRESTORE INTERNAL ASSERTION FAILED: %@", _description]; \
    abort();                                                                               \
  } while (0)

NS_ASSUME_NONNULL_END
