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

#import "FIRInstallationsIIDCheckinStore.h"

#if __has_include(<FBLPromises/FBLPromises.h>)
#import <FBLPromises/FBLPromises.h>
#else
#import "FBLPromises.h"
#endif

#import "FIRInstallationsErrorUtil.h"
#import "FIRInstallationsKeychainUtils.h"
#import "FIRInstallationsStoredIIDCheckin.h"

NSString *const kFIRInstallationsIIDCheckinKeychainGeneric = @"com.google.iid";
NSString *const kFIRFIRInstallationsIIDCheckinKeychainService = @"com.google.iid.checkin";

@implementation FIRInstallationsIIDCheckinStore

- (FBLPromise<FIRInstallationsStoredIIDCheckin *> *)existingCheckin {
  return [[FBLPromise onQueue:dispatch_get_global_queue(QOS_CLASS_UTILITY, 0)
                           do:^id _Nullable {
                             return [self IIDCheckinData];
                           }] onQueue:dispatch_get_global_queue(QOS_CLASS_UTILITY, 0)
                                 then:^id _Nullable(NSData *_Nullable keychainData) {
                                   return [self IIDCheckinWithData:keychainData];
                                 }];
}

- (FBLPromise<FIRInstallationsStoredIIDCheckin *> *)IIDCheckinWithData:(NSData *)data {
  FBLPromise<FIRInstallationsStoredIIDCheckin *> *resultPromise = [FBLPromise pendingPromise];

  NSString *checkinKeychainContent = [[NSString alloc] initWithData:data
                                                           encoding:NSUTF8StringEncoding];
  NSArray<NSString *> *checkinComponents =
      [checkinKeychainContent componentsSeparatedByString:@"|"];

  if (checkinComponents.count < 2) {
    [resultPromise reject:[FIRInstallationsErrorUtil corruptedIIDCheckingData]];
    return resultPromise;
  }

  NSString *deviceID = checkinComponents[0];
  NSString *secret = checkinComponents[1];

  if (deviceID.length < 1 || secret.length < 1) {
    [resultPromise reject:[FIRInstallationsErrorUtil corruptedIIDCheckingData]];
    return resultPromise;
  }

  __auto_type checkin = [[FIRInstallationsStoredIIDCheckin alloc] initWithDeviceID:deviceID
                                                                       secretToken:secret];
  [resultPromise fulfill:checkin];

  return resultPromise;
}

- (FBLPromise<NSData *> *)IIDCheckinData {
  FBLPromise<NSData *> *resultPromise = [FBLPromise pendingPromise];

  NSMutableDictionary *keychainQuery = [self IIDCheckinDataKeychainQuery];
  NSError *error;
  NSData *data = [FIRInstallationsKeychainUtils getItemWithQuery:keychainQuery error:&error];

  if (data) {
    [resultPromise fulfill:data];
    return resultPromise;
  } else if (error) {
    [resultPromise reject:error];
    return resultPromise;
  } else {
    [resultPromise reject:[FIRInstallationsErrorUtil corruptedIIDCheckingData]];
    return resultPromise;
  }
}

- (NSMutableDictionary *)IIDCheckinDataKeychainQuery {
  NSDictionary *query = @{(__bridge id)kSecClass : (__bridge id)kSecClassGenericPassword};

  NSMutableDictionary *finalQuery = [NSMutableDictionary dictionaryWithDictionary:query];
  finalQuery[(__bridge NSString *)kSecAttrGeneric] = kFIRInstallationsIIDCheckinKeychainGeneric;

  NSString *account = [self IIDAppIdentifier];
  if ([account length]) {
    finalQuery[(__bridge NSString *)kSecAttrAccount] = account;
  }

  finalQuery[(__bridge NSString *)kSecAttrService] = kFIRFIRInstallationsIIDCheckinKeychainService;
  return finalQuery;
}

- (NSString *)IIDAppIdentifier {
  return [[NSBundle mainBundle] bundleIdentifier] ?: @"";
}

@end
