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

/**
 * Register the device with Checkin Service and get back the `authID`, `secret token` etc. for the
 * client. Checkin results are cached and periodically refreshed to
 * prevent them from being stale. Each client needs to register with checkin before registering
 * with FIRMessaging.
 */
@interface FIRMessagingCheckinService : NSObject

@property(nonatomic, readonly, strong) NSString *deviceAuthID;
@property(nonatomic, readonly, strong) NSString *secretToken;
@property(nonatomic, readonly, strong) NSString *versionInfo;
@property(nonatomic, readonly, assign) BOOL hasValidCheckinInfo;

/**
 *  Verify if valid checkin preferences have been loaded in memory.
 *
 *  @return YES if valid checkin preferences exist in memory else NO.
 */
- (BOOL)hasValidCheckinInfo;

/**
 *  Try to load prefetched checkin preferences from the cache. This supports the use case where
 *  InstanceID library has already obtained a valid checkin and we should be using that.
 *
 *  This should be used as a last gasp effort to retreive any cached checkin preferences before
 *  hitting the FIRMessaging backend to retrieve new preferences.
 *
 *  Note this is only required because InstanceID and FIRMessaging both require checkin preferences which
 *  need to be synced with each other.
 *
 *  @return YES if successfully loaded cached checkin preferences into memory else NO.
 */
- (BOOL)tryToLoadPrefetchedCheckinPreferences;

@end
