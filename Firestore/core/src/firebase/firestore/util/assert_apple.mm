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

#include "Firestore/core/src/firebase/firestore/util/firebase_assert.h"

#import <Foundation/Foundation.h>

#include <string>

namespace firebase {
namespace firestore {
namespace util {

namespace {

// Translates a C format string to the equivalent NSString without making a
// copy.
NSString* CStringToNSString(const char* format) {
  return [[NSString alloc] initWithBytesNoCopy:(void*)format
                                        length:strlen(format)
                                      encoding:NSUTF8StringEncoding
                                  freeWhenDone:NO];
}

}  // namespace

void FailAssert(const char* file, const char* func, const int line, const char* format, ...) {
  va_list args;
  va_start(args, format);
  NSString *description = [[NSString alloc] initWithFormat:CStringToNSString(format) arguments:args];
  va_end(args);
  [[NSAssertionHandler currentHandler]
      handleFailureInFunction:CStringToNSString(func)
                         file:CStringToNSString(file)
                   lineNumber:line
     description:@"FIRESTORE INTERNAL ASSERTION FAILED: %@", description];
  abort();
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase
