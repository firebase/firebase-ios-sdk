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

#pragma mark - Time

FOUNDATION_EXPORT int64_t FIRMessagingCurrentTimestampInSeconds(void);
FOUNDATION_EXPORT int64_t FIRMessagingCurrentTimestampInMilliseconds(void);

#pragma mark - App Info

FOUNDATION_EXPORT NSString *FIRMessagingCurrentAppVersion(void);
FOUNDATION_EXPORT NSString *FIRMessagingAppIdentifier(void);

#pragma mark - Others

FOUNDATION_EXPORT uint64_t FIRMessagingGetFreeDiskSpaceInMB(void);
FOUNDATION_EXPORT NSSearchPathDirectory FIRMessagingSupportedDirectory(void);
