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

#import "NSDictionary+FIRMessaging.h"

@implementation NSDictionary (FIRMessaging)

- (NSString *)fcm_string {
  NSMutableString *dictAsString = [NSMutableString string];
  NSString *separator = @"|";
  for (id key in self) {
    id value = self[key];
    if ([key isKindOfClass:[NSString class]] && [value isKindOfClass:[NSString class]]) {
      [dictAsString appendFormat:@"%@:%@%@", key, value, separator];
    }
  }
  // remove the last separator
  if ([dictAsString length]) {
    [dictAsString deleteCharactersInRange:NSMakeRange(dictAsString.length - 1, 1)];
  }
  return [dictAsString copy];
}

- (BOOL)fcm_hasNonStringKeysOrValues {
  for (id key in self) {
    id value = self[key];
    if (![key isKindOfClass:[NSString class]] || ![value isKindOfClass:[NSString class]]) {
      return YES;
    }
  }
  return NO;
}

- (NSDictionary *)fcm_trimNonStringValues {
  NSMutableDictionary *trimDictionary = [NSMutableDictionary dictionaryWithCapacity:self.count];
  for (id key in self) {
    id value = self[key];
    if ([key isKindOfClass:[NSString class]] && [value isKindOfClass:[NSString class]]) {
      trimDictionary[(NSString *)key] = value;
    }
  }
  return trimDictionary;
}

@end
