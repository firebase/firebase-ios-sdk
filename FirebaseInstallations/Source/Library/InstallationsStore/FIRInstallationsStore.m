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

#import "FIRInstallationsStore.h"

#import <GoogleUtilities/GULUserDefaults.h>

#if __has_include(<FBLPromises/FBLPromises.h>)
#import <FBLPromises/FBLPromises.h>
#else
#import "FBLPromises.h"
#endif

#import "FIRInstallationsItem.h"
#import "FIRInstallationsStoredItem.h"
#import "FIRSecureStorage.h"

static NSString *const kFIRInstallationsStoreUserDefaultsID = @"com.firebase.FIRInstallations";

@interface FIRInstallationsStore ()
@property(nonatomic, readonly) FIRSecureStorage *secureStorage;
@property(nonatomic, readonly, nullable) NSString *accessGroup;
@property(nonatomic, readonly) dispatch_queue_t queue;
@end

@implementation FIRInstallationsStore

- (instancetype)initWithSecureStorage:(FIRSecureStorage *)storage
                          accessGroup:(NSString *)accessGroup {
  self = [super init];
  if (self) {
    _secureStorage = storage;
    _accessGroup = [accessGroup copy];
    _queue = dispatch_queue_create("com.firebase.FIRInstallationsStore", DISPATCH_QUEUE_SERIAL);
  }
  return self;
}

- (FBLPromise<FIRInstallationsItem *> *)installationForID:(NSString *)identifier {
  return [FBLPromise resolvedWith:nil];
}

- (FBLPromise<NSNull *> *)saveInstallation:(FIRInstallationsItem *)installationItem {
  FIRInstallationsStoredItem *storedItem = [installationItem storedItem];
  NSString *identifier = [installationItem identifier];

  return
      [self.secureStorage setObject:storedItem forKey:identifier accessGroup:self.accessGroup].then(
          ^id(id result) {
            return [self setExists:YES installationItemWithIdentifier:identifier];
          });
}

- (FBLPromise<NSNull *> *)removeInstallationForID:(NSString *)identifier {
  return [FBLPromise resolvedWith:nil];
}

#pragma mark - User defaults

- (FBLPromise<NSNumber *> *)existsInstallationItemWithIdentifier:(NSString *)identifier {
  return [FBLPromise onQueue:self.queue
                          do:^id _Nullable {
                            return [[self userDefaults] objectForKey:identifier];
                          }];
}

- (FBLPromise<NSNull *> *)setExists:(BOOL)exists
     installationItemWithIdentifier:(NSString *)identifier {
  return [FBLPromise onQueue:self.queue
                          do:^id _Nullable {
                            if (exists) {
                              [[self userDefaults] setBool:YES forKey:identifier];
                            } else {
                              [[self userDefaults] removeObjectForKey:identifier];
                            }

                            return [NSNull null];
                          }];
}

- (GULUserDefaults *)userDefaults {
  static GULUserDefaults *userDefaults;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    userDefaults = [[GULUserDefaults alloc] initWithSuiteName:kFIRInstallationsStoreUserDefaultsID];
  });

  return userDefaults;
}

@end
