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

typedef NS_ENUM(NSInteger, FIRInstallationsStatus);

@class FIRInstallationsStoredItem;
@class FIRInstallationsStoredAuthToken;

NS_ASSUME_NONNULL_BEGIN

@interface FIRInstallationsItem : NSObject

@property(nonatomic, readonly, nonnull) NSString *appID;
@property(nonatomic, readonly, nonnull) NSString *firebaseAppName;
@property(nonatomic, nullable) NSString *firebaseInstallationID;
// The `refershToken` is used to authorize the auth token requests.
@property(nonatomic, nullable) NSString *refreshToken;
@property(nonatomic, nullable) FIRInstallationsStoredAuthToken *authToken;
@property(nonatomic, assign) FIRInstallationsStatus registrationStatus;

- (instancetype)initWithAppID:(NSString *)appID firebaseAppName:(NSString *)firebaseAppName;

- (void)updateWithStoredItem:(FIRInstallationsStoredItem *)item;
- (FIRInstallationsStoredItem *)storedItem;

// [NSString stringWithFormat:@"%@+%@", appID, firebaseAppName]
- (nonnull NSString *)identifier;

@end

NS_ASSUME_NONNULL_END
