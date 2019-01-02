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
    if (!str) {
      // TODO(varconst): this happens when `NSData` doesn't happen to contain valid UTF-8, perhaps
      // find a way to still convert it to a string.
      return 0;
    }

    // Create a FieldPath object from a string.
    @try {
      [FIRFieldPath pathWithDotSeparatedString:str];
    } @catch (...) {
      // Ignore caught exceptions.
    }

    // Fuzz test creating a FieldPath from an array with a single string.
    NSArray *str_arr1 = [NSArray arrayWithObjects:str, nil];
    @try {
      (void)[[FIRFieldPath alloc] initWithFields:str_arr1];
    } @catch (...) {
      // Caught exceptions are ignored because they are not what we are after in
      // fuzz testing.
    }

    // Split the string into an array using " .,/-" as separators.
    NSCharacterSet *set = [NSCharacterSet characterSetWithCharactersInString:@" .,/_"];
    NSArray *str_arr2 = [str componentsSeparatedByCharactersInSet:set];
    @try {
      (void)[[FIRFieldPath alloc] initWithFields:str_arr2];
    } @catch (...) {
      // Ignore caught exceptions.
    }

    // Try to parse the bytes as a string array and use it for initialization.
    // NSJSONReadingMutableContainers specifies that arrays and dictionaries are
    // created as mutable objects. Returns nil if there is a parsing error.
    NSArray *str_arr3 = [NSJSONSerialization JSONObjectWithData:d
                                                        options:NSJSONReadingMutableContainers
                                                          error:nil];
    NSMutableArray *mutable_array = [[NSMutableArray alloc] initWithArray:str_arr3];
    if (str_arr3) {
      for (int i = 0; i < str_arr3.count; ++i) {
        NSObject *value = str_arr3[i];
        // `FIRFieldPath initWithFields:` relies on all members having `length` attribute.
        if (![value isKindOfClass:[NSString class]]) {
          if ([value isKindOfClass:[NSNumber class]]) {
            mutable_array[i] = [[NSString alloc] initWithFormat:@"%@", (NSNumber *)value];
          } else {
            // TODO(varconst): convert to string recursively.
            return 0;
          }
        }
      }
    }

    @try {
      if (mutable_array) {
        (void)[[FIRFieldPath alloc] initWithFields:mutable_array];
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
