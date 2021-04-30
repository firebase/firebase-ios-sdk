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

#import "FirebaseAppCheck/Sources/AppAttestProvider/Storage/FIRAppAttestKeyIDStorage.h"

#if __has_include(<FBLPromises/FBLPromises.h>)
#import <FBLPromises/FBLPromises.h>
#else
#import "FBLPromises.h"
#endif

#import "FirebaseAppCheck/Sources/Core/Errors/FIRAppCheckErrorUtil.h"

/// The `NSUserDefaults` suite name for the storage location of the app attest key ID.
static NSString *const kFIRAppAttestKeyIDStorageDefaultsSuiteName = @"com.firebase.FIRAppAttestKeyIDStorage";

/// The key used to retrieve the app attest key ID from its storage suite.
static NSString *const kFIRAppAttestKeyIDKey = @"FIRAppAttestKeyID";

@interface FIRAppAttestKeyIDStorage ()

@property(nonatomic, readonly) NSString *appName;
@property(nonatomic, readonly) NSString *appID;

/// The app attest key ID is stored using `NSUserDefaults` .
@property(nonatomic, readonly) NSUserDefaults *userDefaults;

@end

@implementation FIRAppAttestKeyIDStorage

- (instancetype)initWithAppName:(NSString *)appName appID:(NSString *)appID {
  self = [super init];
  if (self) {
    _appName = [appName copy];
    _appID = [appID copy];
    _userDefaults = [[NSUserDefaults alloc] initWithSuiteName:kFIRAppAttestKeyIDStorageDefaultsSuiteName];
  }
  return self;
}

- (nonnull FBLPromise<NSString *> *)setAppAttestKeyID:(nullable NSString *)keyID {
  [self storeAppAttestKeyID:keyID];
  return [FBLPromise resolvedWith:keyID];
}

- (nonnull FBLPromise<NSString *> *)getAppAttestKeyID {
  NSString *appAttestKeyID = [self appAttestKeyIDFromStorage];
  if (appAttestKeyID) {
    return [FBLPromise resolvedWith:appAttestKeyID];
  } else {
    NSError *error = [FIRAppCheckErrorUtil appAttestKeyIDNotFound];
    FBLPromise *rejectedPromise = [FBLPromise pendingPromise];
    [rejectedPromise reject:error];
    return rejectedPromise;
  }
}

#pragma mark - Helpers

- (void)storeAppAttestKeyID:(nullable NSString *)keyID {
  @synchronized (self.userDefaults) {
    if (keyID) {
      [self.userDefaults setObject:keyID forKey:kFIRAppAttestKeyIDKey];
    } else {
      [self.userDefaults removeObjectForKey:kFIRAppAttestKeyIDKey];
    }
  }
}

- (nullable NSString *)appAttestKeyIDFromStorage {
  NSString *appAttestKeyID = nil;
  @synchronized (self.userDefaults) {
    appAttestKeyID = [self.userDefaults objectForKey:kFIRAppAttestKeyIDKey];
  }
  return appAttestKeyID;
}

@end
