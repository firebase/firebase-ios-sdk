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

    // Create a FieldPath object from a string.
    @try {
      [FIRFieldPath pathWithDotSeparatedString:str];
    } @catch (...) {
      // Ignore caught exceptions.
    }

    // Fuzz test creating a FieldPath from an array with a single string.
    NSArray *str_arr1 = [NSArray arrayWithObjects:str, nil];
    @try {
      [[FIRFieldPath alloc] initWithFields:str_arr1];
    } @catch (...) {
      // Caught exceptions are ignored because they are not what we are after in
      // fuzz testing.
    }

    // Split the string into an array using " .,/-" as separators.
    NSCharacterSet *set = [NSCharacterSet characterSetWithCharactersInString:@" .,/_"];
    NSArray *str_arr2 = [str componentsSeparatedByCharactersInSet:set];
    @try {
      [[FIRFieldPath alloc] initWithFields:str_arr2];
    } @catch (...) {
      // Ignore caught exceptions.
    }

    // Try to parse the bytes as a string array and use it for initialization.
    // NSJSONReadingMutableContainers specifies that arrays and dictionaries are
    // created as mutable objects. Returns nil if there is a parsing error.
    NSArray *str_arr3 =
        [NSJSONSerialization JSONObjectWithData:d options:NSJSONReadingMutableContainers error:nil];
    @try {
      if (str_arr3) {
        [[FIRFieldPath alloc] initWithFields:str_arr3];
      }
    } @catch (...) {
      // Ignore caught exceptions.
    }
  }
  return 0;
}

}  // namespace fuzzing
}  // namespace firestore
}  // namespace firebase
