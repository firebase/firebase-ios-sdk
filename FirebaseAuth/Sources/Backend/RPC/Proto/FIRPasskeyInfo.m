/*
 * Copyright 2023 Google LLC
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

#import "FirebaseAuth/Sources/Public/FirebaseAuth/FIRPasskeyInfo.h"

NS_ASSUME_NONNULL_BEGIN

/**
 @var kNameKey
 @brief The name of the field in the response JSON for name.
 */
static const NSString *kNameKey = @"name";

/**
 @var kCredentialIdKey
 @brief The name of the field in the response JSON for credential ID.
 */
static const NSString *kCredentialIdKey = @"credentialId";

@implementation FIRPasskeyInfo

- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
  self = [super init];
  if (self) {
    if (dictionary[kNameKey]) {
      _name = dictionary[kNameKey];
    }
    if (dictionary[kCredentialIdKey]) {
      _credentialID = dictionary[kCredentialIdKey];
    }
  }
  return self;
}

@end

NS_ASSUME_NONNULL_END
