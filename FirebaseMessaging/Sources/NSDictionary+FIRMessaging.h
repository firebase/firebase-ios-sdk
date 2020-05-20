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

#import <Foundation/Foundation.h>

@interface NSDictionary (FIRMessaging)

/**
 *  Returns a string representation for the given dictionary. Assumes that all
 *  keys and values are strings.
 *
 *  @return A string representation of all keys and values in the dictionary.
 *          The returned string is not pretty-printed.
 */
- (NSString *)fcm_string;

/**
 *  Check if the dictionary has any non-string keys or values.
 *
 *  @return YES if the dictionary has any non-string keys or values else NO.
 */
- (BOOL)fcm_hasNonStringKeysOrValues;

/**
 *  Trims all (key, value) pair in a dictionary that are not strings.
 *
 *  @return A new copied dictionary with all the non-string keys or values
 *          removed from the original dictionary.
 */
- (NSDictionary *)fcm_trimNonStringValues;

@end
