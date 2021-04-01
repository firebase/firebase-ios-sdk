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

#import <Foundation/Foundation.h>

@class FIRMessagingAuthKeychain;
@class FIRMessagingBackupExcludedPlist;
@class FIRMessagingCheckinPreferences;

// These values exposed for testing
extern NSString *const kFIRMessagingCheckinKeychainService;

/**
 *  Checkin preferences backing store.
 */
@interface FIRMessagingCheckinStore : NSObject

/**
 *  Checks whether the backup excluded checkin preferences are present on the disk or not.
 *
 *  @return YES if the backup excluded checkin plist exists on the disks else NO.
 */
- (BOOL)hasCheckinPlist;

#pragma mark - Save

/**
 *  Save the checkin preferences to backing store.
 *
 *  @param preferences   Checkin preferences to save.
 *  @param handler       The callback handler which is invoked when the operation is complete,
 *                       with an error if there is any.
 */
- (void)saveCheckinPreferences:(FIRMessagingCheckinPreferences *)preferences
                       handler:(void (^)(NSError *error))handler;

#pragma mark - Delete

/**
 *  Remove the cached checkin preferences.
 *
 *  @param handler       The callback handler which is invoked when the operation is complete,
 *                       with an error if there is any.
 */
- (void)removeCheckinPreferencesWithHandler:(void (^)(NSError *error))handler;

#pragma mark - Get

/**
 *  Get the cached device secret. If we cannot access it for some reason we
 *  return the appropriate error object.
 *
 *  @return The cached checkin preferences if present else nil.
 */
- (FIRMessagingCheckinPreferences *)cachedCheckinPreferences;

@end
