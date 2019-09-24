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

#include "Firestore/core/src/firebase/firestore/util/hard_assert_apple.h"

#import <Foundation/Foundation.h>

#include "Firestore/core/src/firebase/firestore/util/string_apple.h"

namespace firebase {
namespace firestore {
namespace util {

ABSL_ATTRIBUTE_NORETURN void ObjcFailureHandler(const char* file,
                                                const char* func,
                                                const int line,
                                                const std::string& message) {
  [[NSAssertionHandler currentHandler]
      handleFailureInFunction:MakeNSString(func)
                         file:MakeNSString(file)
                   lineNumber:line
                  description:@"FIRESTORE INTERNAL ASSERTION FAILED: %s",
                              message.c_str()];
  abort();
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase
