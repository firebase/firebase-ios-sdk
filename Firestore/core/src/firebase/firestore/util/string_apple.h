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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_UTIL_STRING_APPLE_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_UTIL_STRING_APPLE_H_

#import <Foundation/Foundation.h>

namespace firebase {
namespace firestore {
namespace util {

// Translates a C string to the equivalent NSString without making a copy.
inline NSString* WrapNSStringNoCopy(const char* c_str) {
  return [[NSString alloc]
      initWithBytesNoCopy:const_cast<void*>(static_cast<const void*>(c_str))
                   length:strlen(c_str)
                 encoding:NSUTF8StringEncoding
             freeWhenDone:NO];
}

}  // namespace util
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_UTIL_STRING_APPLE_H_
