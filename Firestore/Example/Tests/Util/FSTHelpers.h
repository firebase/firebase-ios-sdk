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

// Remove possible exception-prefix.
NSString *FSTRemoveExceptionPrefix(NSString *exception);

// Helper for validating API exceptions.
#define FSTAssertThrows(expression, exceptionReason, ...)               \
  do {                                                                  \
    BOOL didThrow = NO;                                                 \
    @try {                                                              \
      (void)(expression);                                               \
    } @catch (NSException * exception) {                                \
      didThrow = YES;                                                   \
      XCTAssertEqualObjects(FSTRemoveExceptionPrefix(exception.reason), \
                            FSTRemoveExceptionPrefix(exceptionReason)); \
    }                                                                   \
    XCTAssertTrue(didThrow, ##__VA_ARGS__);                             \
  } while (0)

NS_ASSUME_NONNULL_END
