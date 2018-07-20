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
    @try {
      NSArray *str_arr1 = [NSArray arrayWithObjects:str, nil];
      [[FIRFieldPath alloc] initWithFields:str_arr1];
    } @catch (...) {}

    @try {
      NSCharacterSet *set = [NSCharacterSet characterSetWithCharactersInString:@" .,/_"];
      NSArray *str_arr2 = [str componentsSeparatedByCharactersInSet:set];
      [[FIRFieldPath alloc] initWithFields:str_arr2];
    } @catch (...) {}

    @try {
      [FIRFieldPath pathWithDotSeparatedString:str];
    } @catch (...) {}
  }
  return 0;
}

}  // namespace fuzzing
}  // namespace firestore
}  // namespace firebase
