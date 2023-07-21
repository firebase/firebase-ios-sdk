/*
 * Copyright 2021 Google LLC
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

#import "AppCheckCore/Sources/Core/TokenRefresh/GACAppCheckTokenRefreshResult.h"

NS_ASSUME_NONNULL_BEGIN

@interface GACAppCheckTokenRefreshResult ()

- (instancetype)initWithStatus:(GACAppCheckTokenRefreshStatus)status
                expirationDate:(nullable NSDate *)tokenExpirationDate
                receivedAtDate:(nullable NSDate *)tokenReceivedAtDate NS_DESIGNATED_INITIALIZER;

@end

@implementation GACAppCheckTokenRefreshResult

- (instancetype)initWithStatus:(GACAppCheckTokenRefreshStatus)status
                expirationDate:(nullable NSDate *)tokenExpirationDate
                receivedAtDate:(nullable NSDate *)tokenReceivedAtDate {
  self = [super init];
  if (self) {
    _status = status;
    _tokenExpirationDate = tokenExpirationDate;
    _tokenReceivedAtDate = tokenReceivedAtDate;
  }
  return self;
}

- (instancetype)initWithStatusNever {
  return [self initWithStatus:GACAppCheckTokenRefreshStatusNever
               expirationDate:nil
               receivedAtDate:nil];
}

- (instancetype)initWithStatusFailure {
  return [self initWithStatus:GACAppCheckTokenRefreshStatusFailure
               expirationDate:nil
               receivedAtDate:nil];
}

- (instancetype)initWithStatusSuccessAndExpirationDate:(NSDate *)tokenExpirationDate
                                        receivedAtDate:(NSDate *)tokenReceivedAtDate {
  return [self initWithStatus:GACAppCheckTokenRefreshStatusSuccess
               expirationDate:tokenExpirationDate
               receivedAtDate:tokenReceivedAtDate];
}

@end

NS_ASSUME_NONNULL_END
