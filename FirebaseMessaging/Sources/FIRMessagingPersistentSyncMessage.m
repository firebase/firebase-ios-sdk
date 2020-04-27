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

#import "FirebaseMessaging/Sources/FIRMessagingPersistentSyncMessage.h"

#import "FirebaseMessaging/Sources/FIRMessagingDefines.h"

@interface FIRMessagingPersistentSyncMessage ()

@property(nonatomic, readwrite, strong) NSString *rmqID;
@property(nonatomic, readwrite, assign) int64_t expirationTime;

@end

@implementation FIRMessagingPersistentSyncMessage

- (instancetype)init {
  FIRMessagingInvalidateInitializer();
}

- (instancetype)initWithRMQID:(NSString *)rmqID expirationTime:(int64_t)expirationTime {
  self = [super init];
  if (self) {
    _rmqID = [rmqID copy];
    _expirationTime = expirationTime;
  }
  return self;
}

- (NSString *)description {
  NSString *classDescription = NSStringFromClass([self class]);
  NSDate *date = [NSDate dateWithTimeIntervalSince1970:self.expirationTime];
  return
      [NSString stringWithFormat:@"%@: (rmqID: %@, apns: %d, mcs: %d, expiry: %@", classDescription,
                                 self.rmqID, self.mcsReceived, self.apnsReceived, date];
}

- (NSString *)debugDescription {
  return [self description];
}

@end
