/*
 * Copyright 2019 Google
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

#import "NSString+FIRInterlaceStrings.h"

@implementation NSString (InterlaceStrings)

+ (NSString *)fir_interlaceString:(NSString *)stringOne withString:(NSString *)stringTwo {
  NSMutableString *interlacedString = [NSMutableString string];

  NSUInteger count = MAX(stringOne.length, stringTwo.length);

  for (NSUInteger i = 0; i < count; i++) {
    if (i < stringOne.length) {
      NSString *firstComponentChar =
          [NSString stringWithFormat:@"%c", [stringOne characterAtIndex:i]];
      [interlacedString appendString:firstComponentChar];
    }
    if (i < stringTwo.length) {
      NSString *secondComponentChar =
          [NSString stringWithFormat:@"%c", [stringTwo characterAtIndex:i]];
      [interlacedString appendString:secondComponentChar];
    }
  }

  return interlacedString;
}

@end
