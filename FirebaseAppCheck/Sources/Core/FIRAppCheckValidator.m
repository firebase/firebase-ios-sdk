/*
 * Copyright 2020 Google LLC
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

#import "FirebaseAppCheck/Sources/Core/FIRAppCheckValidator.h"

#import "FirebaseCore/Extension/FirebaseCoreInternal.h"

@implementation FIRAppCheckValidator

+ (NSArray<NSString *> *)tokenExchangeMissingFieldsInOptions:(FIROptions *)options {
  NSMutableArray<NSString *> *missingFields = [NSMutableArray array];

  if (options.APIKey.length < 1) {
    [missingFields addObject:@"APIKey"];
  }

  if (options.projectID.length < 1) {
    [missingFields addObject:@"projectID"];
  }

  if (options.googleAppID.length < 1) {
    [missingFields addObject:@"googleAppID"];
  }

  return [missingFields copy];
}

@end
