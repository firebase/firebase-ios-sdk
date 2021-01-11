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

#import <Foundation/Foundation.h>

#pragma mark - URL Helpers

FOUNDATION_EXPORT NSString *FIRMessagingTokenRegisterServer(void);

#pragma mark - Time

FOUNDATION_EXPORT int64_t FIRMessagingCurrentTimestampInSeconds(void);
FOUNDATION_EXPORT int64_t FIRMessagingCurrentTimestampInMilliseconds(void);

#pragma mark - App Info

FOUNDATION_EXPORT NSString *FIRMessagingCurrentAppVersion(void);
FOUNDATION_EXPORT NSString *FIRMessagingAppIdentifier(void);
FOUNDATION_EXPORT NSString *FIRMessagingFirebaseAppID(void);

#pragma mark - Others

FOUNDATION_EXPORT uint64_t FIRMessagingGetFreeDiskSpaceInMB(void);
FOUNDATION_EXPORT NSSearchPathDirectory FIRMessagingSupportedDirectory(void);

#pragma mark - Device Info
FOUNDATION_EXPORT NSString *FIRMessagingCurrentLocale(void);
FOUNDATION_EXPORT BOOL FIRMessagingHasLocaleChanged(void);
/// locale key stored in GULUserDefaults
FOUNDATION_EXPORT NSString *const kFIRMessagingInstanceIDUserDefaultsKeyLocale;

FOUNDATION_EXPORT NSString *FIRMessagingStringForAPNSDeviceToken(NSData *deviceToken);
FOUNDATION_EXPORT NSString *FIRMessagingAPNSTupleStringForTokenAndServerType(NSData *deviceToken,
                                                                             BOOL isSandbox);

FOUNDATION_EXPORT BOOL FIRMessagingIsSandboxApp(void);
