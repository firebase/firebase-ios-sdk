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

#import "FirebaseMessaging/Tests/UnitTests/FIRMessagingFakeKeychain.h"

static NSString *const kFakeKeychainErrorDomain = @"com.google.iid";

@interface FIRMessagingFakeKeychain ()

@property(nonatomic, readwrite, strong) NSMutableDictionary *data;

@end

@implementation FIRMessagingFakeKeychain

- (instancetype)init {
  self = [super init];
  if (self) {
    _data = [NSMutableDictionary dictionary];
  }
  return self;
}

- (NSArray<NSData *> *)itemsMatchingService:(NSString *)service account:(NSString *)account {
  if (self.cannotReadFromKeychain) {
    return @[];
  }
  NSMutableArray<NSData *> *results = [NSMutableArray array];
  BOOL accountIsWildcard = [account isEqualToString:kFIRMessagingKeychainWildcardIdentifier];
  BOOL serviceIsWildcard = [service isEqualToString:kFIRMessagingKeychainWildcardIdentifier];
  for (NSString *accountKey in [self.data allKeys]) {
    if (!accountIsWildcard && ![accountKey isEqualToString:account]) {
      continue;
    }
    NSDictionary *services = self.data[accountKey];
    for (NSString *serviceKey in [services allKeys]) {
      if (!serviceIsWildcard && ![serviceKey isEqualToString:service]) {
        continue;
      }
      NSData *item = self.data[accountKey][serviceKey];
      [results addObject:item];
    }
  }
  return results;
}

- (NSData *)dataForService:(NSString *)service account:(NSString *)account {
  if (self.cannotReadFromKeychain) {
    return nil;
  }
  return self.data[account][service];
}

- (void)removeItemsMatchingService:(NSString *)service
                           account:(NSString *)account
                           handler:(void (^)(NSError *error))handler {
  if (self.cannotWriteToKeychain) {
    if (handler) {
      handler([NSError errorWithDomain:kFakeKeychainErrorDomain code:1001 userInfo:nil]);
    }
    return;
  }
  if ([account isEqualToString:kFIRMessagingKeychainWildcardIdentifier]) {
    // Remove all account keys.
    [self.data removeAllObjects];
  } else {
    if ([service isEqualToString:kFIRMessagingKeychainWildcardIdentifier]) {
      // Remove all service keys for this account key.
      [self.data[account] removeAllObjects];
    } else {
      [self.data[account] removeObjectForKey:service];
    }
  }
  if (handler) {
    handler(nil);
  }
}

- (void)setData:(NSData *)data
     forService:(NSString *)service
        account:(NSString *)account
        handler:(void (^)(NSError *error))handler {
  if (self.cannotWriteToKeychain) {
    if (handler) {
      handler([NSError errorWithDomain:kFakeKeychainErrorDomain code:1001 userInfo:nil]);
    }
    return;
  }
  if (!self.data[account]) {
    self.data[account] = [NSMutableDictionary dictionary];
  }
  self.data[account][service] = data;
  if (handler) {
    handler(nil);
  }
}

@end
