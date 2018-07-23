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
#include <cstddef>
#include <cstdint>

#import "Firestore/Example/FuzzTests/FuzzingTargets/FSTFuzzTestFieldPath.h"

#import "Firestore/Source/API/FIRFieldPath+Internal.h"

namespace firebase {
namespace firestore {
namespace fuzzing {

int FuzzTestFieldPath(const uint8_t *data, size_t size) {
  @autoreleasepool {
    // Convert the raw bytes to a string with UTF-8 format.
    NSData *d = [NSData dataWithBytes:data length:size];
    NSString *str = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];

    // Fuzz test creating a FieldPath from a signle string.
    @try {
      NSArray *str_arr = [NSArray arrayWithObjects:str, nil];
      [[FIRFieldPath alloc] initWithFields:str_arr];
    } @catch (...) {
      // Caught exceptions are ignored because they are not what we are after in
      // fuzz testing.
    }

    // Split the string into an array. Use " .,/-" as separators.
    @try {
      NSCharacterSet *set = [NSCharacterSet characterSetWithCharactersInString:@" .,/_"];
      NSArray *str_arr = [str componentsSeparatedByCharactersInSet:set];
      [[FIRFieldPath alloc] initWithFields:str_arr];
    } @catch (...) {
      // Caught exceptions are ignored because they are not what we are after in
      // fuzz testing.
    }

    // Treat the string as a dot-separated string and create a FieldPath object.
    @try {
      [FIRFieldPath pathWithDotSeparatedString:str];
    } @catch (...) {
      // Caught exceptions are ignored because they are not what we are after in
      // fuzz testing.
    }
  }
  return 0;
}

}  // namespace fuzzing
}  // namespace firestore
}  // namespace firebase
