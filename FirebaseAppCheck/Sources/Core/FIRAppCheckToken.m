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

#import "FirebaseAppCheck/Sources/Core/FIRAppCheckToken+Internal.h"

NS_ASSUME_NONNULL_BEGIN

@implementation FIRAppCheckToken

- (instancetype)initWithToken:(NSString *)token
               expirationDate:(NSDate *)expirationDate
               receivedAtDate:(NSDate *)receivedAtDate {
  self = [super init];
  if (self) {
    _token = [token copy];
    _expirationDate = expirationDate;
    _receivedAtDate = receivedAtDate;
  }
  return self;
}

- (instancetype)initWithToken:(NSString *)token expirationDate:(NSDate *)expirationDate {
  return [self initWithToken:token expirationDate:expirationDate receivedAtDate:[NSDate date]];
}

- (instancetype)initWithInternalToken:(GACAppCheckToken *)token {
  return [self initWithToken:token.token
              expirationDate:token.expirationDate
              receivedAtDate:token.receivedAtDate];
}

- (GACAppCheckToken *)internalToken {
  return [[GACAppCheckToken alloc] initWithToken:self.token
                                  expirationDate:self.expirationDate
                                  receivedAtDate:self.receivedAtDate];
}

@end

NS_ASSUME_NONNULL_END
