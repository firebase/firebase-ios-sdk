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

// TODO: Add short docs to the undocumented API.
#import <Foundation/Foundation.h>

#import "FIRInstallationsStatus.h"

@class FIRInstallationsStoredItem;
@class FIRInstallationsStoredAuthToken;

NS_ASSUME_NONNULL_BEGIN

/**
 * The class represents the required installation ID and auth token data including possible states.
 * The data is stored to Keychain via `FIRInstallationsStoredItem` which has only the storage
 * relevant data and does not contain any logic. `FIRInstallationsItem` must be used on the logic
 * level (not `FIRInstallationsStoredItem`).
 */
@interface FIRInstallationsItem : NSObject

@property(nonatomic, readonly) NSString *appID;
@property(nonatomic, readonly) NSString *firebaseAppName;
@property(nonatomic, copy, nullable) NSString *firebaseInstallationID;
/// The `refreshToken` is used to authorize the auth token requests.
@property(nonatomic, copy, nullable) NSString *refreshToken;
@property(nonatomic, nullable) FIRInstallationsStoredAuthToken *authToken;
@property(nonatomic, assign) FIRInstallationsStatus registrationStatus;

- (instancetype)initWithAppID:(NSString *)appID firebaseAppName:(NSString *)firebaseAppName;

- (void)updateWithStoredItem:(FIRInstallationsStoredItem *)item;
- (FIRInstallationsStoredItem *)storedItem;

- (NSString *)identifier;

+ (NSString *)identifierWithAppID:(NSString *)appID appName:(NSString *)appName;

+ (NSString *)generateFID;

@end

NS_ASSUME_NONNULL_END
