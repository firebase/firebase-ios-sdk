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

#import "FirebaseMessaging/Sources/Token/FIRMessagingCheckinStore.h"

#import "FirebaseMessaging/Sources/FIRMessagingCode.h"
#import "FirebaseMessaging/Sources/FIRMessagingConstants.h"
#import "FirebaseMessaging/Sources/FIRMessagingLogger.h"
#import "FirebaseMessaging/Sources/FIRMessagingUtilities.h"
#import "FirebaseMessaging/Sources/NSError+FIRMessaging.h"
#import "FirebaseMessaging/Sources/Token/FIRMessagingAuthKeychain.h"
#import "FirebaseMessaging/Sources/Token/FIRMessagingBackupExcludedPlist.h"
#import "FirebaseMessaging/Sources/Token/FIRMessagingCheckinPreferences.h"
#import "FirebaseMessaging/Sources/Token/FIRMessagingCheckinService.h"

// NOTE: These values should be in sync with what InstanceID saves in as.
static NSString *const kCheckinFileName = @"g-checkin";
static NSString *const kFIRMessagingCheckinKeychainGeneric = @"com.google.iid";
NSString *const kFIRMessagingCheckinKeychainService = @"com.google.iid.checkin";

@interface FIRMessagingCheckinStore ()

@property(nonatomic, readwrite, strong) FIRMessagingBackupExcludedPlist *plist;
@property(nonatomic, readwrite, strong) FIRMessagingAuthKeychain *keychain;
// Checkin will store items under
// Keychain account: <app bundle id>,
// Keychain service: |kFIRMessagingCheckinKeychainService|
@property(nonatomic, readonly) NSString *bundleIdentifierForKeychainAccount;

@end

@implementation FIRMessagingCheckinStore

- (instancetype)init {
  self = [super init];
  if (self) {
    _plist = [[FIRMessagingBackupExcludedPlist alloc]
        initWithFileName:kCheckinFileName
            subDirectory:kFIRMessagingInstanceIDSubDirectoryName];
    _keychain =
        [[FIRMessagingAuthKeychain alloc] initWithIdentifier:kFIRMessagingCheckinKeychainGeneric];
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
    bundleIdentifier = FIRMessagingAppIdentifier();
  });
  return bundleIdentifier;
}

- (void)saveCheckinPreferences:(FIRMessagingCheckinPreferences *)preferences
                       handler:(void (^)(NSError *error))handler {
  NSDictionary *checkinPlistContents = [preferences checkinPlistContents];
  NSString *checkinKeychainContent = [preferences checkinKeychainContent];

  if (![checkinKeychainContent length]) {
    NSString *failureReason = @"Failed to get checkin keychain content from memory.";
    FIRMessagingLoggerDebug(kFIRMessagingMessageCodeCheckinStore000, @"%@", failureReason);
    if (handler) {
      handler([NSError messagingErrorWithCode:kFIRMessagingErrorCodeRegistrarFailedToCheckIn
                                failureReason:failureReason]);
    }
    return;
  }
  if (![checkinPlistContents count]) {
    NSString *failureReason = @"Failed to get checkin plist contents from memory.";
    FIRMessagingLoggerDebug(kFIRMessagingMessageCodeCheckinStore001, @"%@", failureReason);
    if (handler) {
      handler([NSError messagingErrorWithCode:kFIRMessagingErrorCodeRegistrarFailedToCheckIn
                                failureReason:failureReason]);
    }
    return;
  }

  // Save all other checkin preferences in a plist
  NSError *error;
  if (![self.plist writeDictionary:checkinPlistContents error:&error]) {
    FIRMessagingLoggerDebug(kFIRMessagingMessageCodeCheckinStore003,
                            @"Failed to save checkin plist contents."
                            @"Will delete auth credentials");
    [self.keychain removeItemsMatchingService:kFIRMessagingCheckinKeychainService
                                      account:self.bundleIdentifierForKeychainAccount
                                      handler:nil];
    if (handler) {
      handler(error);
    }
    return;
  }
  FIRMessagingLoggerDebug(kFIRMessagingMessageCodeCheckinStoreCheckinPlistSaved,
                          @"Checkin plist file is saved");

  // Save the deviceID and secret in the Keychain
  if (!preferences.hasPreCachedAuthCredentials) {
    NSData *data = [checkinKeychainContent dataUsingEncoding:NSUTF8StringEncoding];
    [self.keychain setData:data
                forService:kFIRMessagingCheckinKeychainService
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
  FIRMessagingLoggerDebug(kFIRMessagingMessageCodeCheckinStoreCheckinPlistDeleted,
                          @"Deleted checkin plist file.");
  // Remove deviceID and secret from Keychain
  [self.keychain removeItemsMatchingService:kFIRMessagingCheckinKeychainService
                                    account:self.bundleIdentifierForKeychainAccount
                                    handler:^(NSError *error) {
                                      handler(error);
                                    }];
}

- (FIRMessagingCheckinPreferences *)cachedCheckinPreferences {
  // Query the keychain for deviceID and secret
  NSData *item = [self.keychain dataForService:kFIRMessagingCheckinKeychainService
                                       account:self.bundleIdentifierForKeychainAccount];

  // Check info found in keychain
  NSString *checkinKeychainContent = [[NSString alloc] initWithData:item
                                                           encoding:NSUTF8StringEncoding];
  FIRMessagingCheckinPreferences *checkinPreferences = [FIRMessagingCheckinPreferences
      preferencesFromKeychainContents:[checkinKeychainContent copy]];

  NSDictionary *checkinPlistContents = [self.plist contentAsDictionary];

  NSString *plistDeviceAuthID = checkinPlistContents[kFIRMessagingDeviceAuthIdKey];
  NSString *plistSecretToken = checkinPlistContents[kFIRMessagingSecretTokenKey];

  // If deviceID and secret not found in the keychain verify that we don't have them in the
  // checkin preferences plist.
  if (![checkinPreferences.deviceID length] && ![checkinPreferences.secretToken length]) {
    if ([plistDeviceAuthID length] && [plistSecretToken length]) {
      // Couldn't find checkin credentials in keychain but found them in the plist.
      checkinPreferences =
          [[FIRMessagingCheckinPreferences alloc] initWithDeviceID:plistDeviceAuthID
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
