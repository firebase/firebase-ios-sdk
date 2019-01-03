/*
 * Copyright 2018 Google
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

/** A block type that could be run instead of NSAssert. No return type, no params. */
typedef void (^GDLAssertionBlock)(void);

/** Returns the result of executing a soft-linked method present in unit tests that allows a block
 * to be run in lieu of a call to NSAssert. This helps ameliorate issues with catching exceptions
 * that occur on a dispatch_queue.
 *
 * @return A block that can be run instead of calling NSAssert, or nil.
 */
FOUNDATION_EXTERN GDLAssertionBlock _Nullable GDLAssertionBlockToRunInsteadOfNSAssert(void);

/** Asserts using NSAssert, unless a block was specified to be run instead.
 *
 * @param condition The condition you'd expect to be YES.
 */
#define GDLAssert(condition, ...)                                                   \
  do {                                                                              \
    if (__builtin_expect(!(condition), 0)) {                                       \
      GDLAssertionBlock assertionBlock = GDLAssertionBlockToRunInsteadOfNSAssert(); \
      if (assertionBlock) {                                                         \
        assertionBlock();                                                           \
      } else {                                                                      \
        NSAssert(condition, __VA_ARGS__);                                           \
      }                                                                             \
    }                                                                               \
  } while (0);
