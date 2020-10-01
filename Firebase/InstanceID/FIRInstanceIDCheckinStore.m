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

#import "Firebase/InstanceID/FIRInstanceIDCheckinStore.h"

#import "Firebase/InstanceID/FIRInstanceIDAuthKeyChain.h"
#import "Firebase/InstanceID/FIRInstanceIDBackupExcludedPlist.h"
#import "Firebase/InstanceID/FIRInstanceIDCheckinPreferences+Internal.h"
#import "Firebase/InstanceID/FIRInstanceIDCheckinPreferences_Private.h"
#import "Firebase/InstanceID/FIRInstanceIDCheckinService.h"
#import "Firebase/InstanceID/FIRInstanceIDLogger.h"
#import "Firebase/InstanceID/FIRInstanceIDUtilities.h"
#import "Firebase/InstanceID/NSError+FIRInstanceID.h"

static NSString *const kFIRInstanceIDCheckinKeychainGeneric = @"com.google.iid";

NSString *const kFIRInstanceIDCheckinKeychainService = @"com.google.iid.checkin";

@interface FIRInstanceIDCheckinStore ()

@property(nonatomic, readwrite, strong) FIRInstanceIDBackupExcludedPlist *plist;
@property(nonatomic, readwrite, strong) FIRInstanceIDAuthKeychain *keychain;
// Checkin will store items under
// Keychain account: <app bundle id>,
// Keychain service: |kFIRInstanceIDCheckinKeychainService|
@property(nonatomic, readonly) NSString *bundleIdentifierForKeychainAccount;

@end

@implementation FIRInstanceIDCheckinStore

- (instancetype)initWithCheckinPlistFileName:(NSString *)checkinFilename
                            subDirectoryName:(NSString *)subDirectoryName {
  FIRInstanceIDBackupExcludedPlist *plist =
      [[FIRInstanceIDBackupExcludedPlist alloc] initWithFileName:checkinFilename
                                                    subDirectory:subDirectoryName];

  FIRInstanceIDAuthKeychain *keychain =
      [[FIRInstanceIDAuthKeychain alloc] initWithIdentifier:kFIRInstanceIDCheckinKeychainGeneric];
  return [self initWithCheckinPlist:plist keychain:keychain];
}

- (instancetype)initWithCheckinPlist:(FIRInstanceIDBackupExcludedPlist *)plist
                            keychain:(FIRInstanceIDAuthKeychain *)keychain {
  self = [super init];
  if (self) {
    _plist = plist;
    _keychain = keychain;
  }
  return self;
}

- (BOOL)hasCheckinPlist {
  return [self.plist doesFileExist];
}

- (NSString *)bundleIdentifierForKeychainAccount {
  static NSString *bundleIdentifier;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    bundleIdentifier = FIRInstanceIDAppIdentifier();
  });
  return bundleIdentifier;
}

- (void)saveCheckinPreferences:(FIRInstanceIDCheckinPreferences *)preferences
                       handler:(void (^)(NSError *error))handler {
  NSDictionary *checkinPlistContents = [preferences checkinPlistContents];
  NSString *checkinKeychainContent = [preferences checkinKeychainContent];

  if (![checkinKeychainContent length]) {
    FIRInstanceIDLoggerDebug(kFIRInstanceIDMessageCodeCheckinStore000,
                             @"Failed to get checkin keychain content from memory.");
    if (handler) {
      handler([NSError
          errorWithFIRInstanceIDErrorCode:kFIRInstanceIDErrorCodeRegistrarFailedToCheckIn]);
    }
    return;
  }
  if (![checkinPlistContents count]) {
    FIRInstanceIDLoggerDebug(kFIRInstanceIDMessageCodeCheckinStore001,
                             @"Failed to get checkin plist contents from memory.");
    if (handler) {
      handler([NSError
          errorWithFIRInstanceIDErrorCode:kFIRInstanceIDErrorCodeRegistrarFailedToCheckIn]);
    }
    return;
  }

  // Save all other checkin preferences in a plist
  NSError *error;
  if (![self.plist writeDictionary:checkinPlistContents error:&error]) {
    FIRInstanceIDLoggerDebug(kFIRInstanceIDMessageCodeCheckinStore003,
                             @"Failed to save checkin plist contents."
                             @"Will delete auth credentials");
    [self.keychain removeItemsMatchingService:kFIRInstanceIDCheckinKeychainService
                                      account:self.bundleIdentifierForKeychainAccount
                                      handler:nil];
    if (handler) {
      handler(error);
    }
    return;
  }
  FIRInstanceIDLoggerDebug(kFIRInstanceIDMessageCodeCheckinStoreCheckinPlistSaved,
                           @"Checkin plist file is saved");

  // Save the deviceID and secret in the Keychain
  if (!preferences.hasPreCachedAuthCredentials) {
    NSData *data = [checkinKeychainContent dataUsingEncoding:NSUTF8StringEncoding];
    [self.keychain setData:data
                forService:kFIRInstanceIDCheckinKeychainService
                   account:self.bundleIdentifierForKeychainAccount
                   handler:^(NSError *error) {
                     if (error) {
                       if (handler) {
                         handler(error);
                       }
                       return;
                     }
                     if (handler) {
                       handler(nil);
                     }
                   }];
  } else {
    handler(nil);
  }
}

- (void)removeCheckinPreferencesWithHandler:(void (^)(NSError *error))handler {
  // Delete the checkin preferences plist first to avoid delay.
  NSError *deletePlistError;
  if (![self.plist deleteFile:&deletePlistError]) {
    handler(deletePlistError);
    return;
  }
  FIRInstanceIDLoggerDebug(kFIRInstanceIDMessageCodeCheckinStoreCheckinPlistDeleted,
                           @"Deleted checkin plist file.");
  // Remove deviceID and secret from Keychain
  [self.keychain removeItemsMatchingService:kFIRInstanceIDCheckinKeychainService
                                    account:self.bundleIdentifierForKeychainAccount
                                    handler:^(NSError *error) {
                                      handler(error);
                                    }];
}

- (FIRInstanceIDCheckinPreferences *)cachedCheckinPreferences {
  // Query the keychain for deviceID and secret
  NSData *item = [self.keychain dataForService:kFIRInstanceIDCheckinKeychainService
                                       account:self.bundleIdentifierForKeychainAccount];

  // Check info found in keychain
  NSString *checkinKeychainContent = [[NSString alloc] initWithData:item
                                                           encoding:NSUTF8StringEncoding];
  FIRInstanceIDCheckinPreferences *checkinPreferences =
      [FIRInstanceIDCheckinPreferences preferencesFromKeychainContents:checkinKeychainContent];

  NSDictionary *checkinPlistContents = [self.plist contentAsDictionary];

  NSString *plistDeviceAuthID = checkinPlistContents[kFIRInstanceIDDeviceAuthIdKey];
  NSString *plistSecretToken = checkinPlistContents[kFIRInstanceIDSecretTokenKey];

  // If deviceID and secret not found in the keychain verify that we don't have them in the
  // checkin preferences plist.
  if (![checkinPreferences.deviceID length] && ![checkinPreferences.secretToken length]) {
    if ([plistDeviceAuthID length] && [plistSecretToken length]) {
      // Couldn't find checkin credentials in keychain but found them in the plist.
      checkinPreferences =
          [[FIRInstanceIDCheckinPreferences alloc] initWithDeviceID:plistDeviceAuthID
                                                        secretToken:plistSecretToken];
    } else {
      // Couldn't find checkin credentials in keychain nor plist
      return nil;
    }
  }

  [checkinPreferences updateWithCheckinPlistContents:checkinPlistContents];
  return checkinPreferences;
}

@end
