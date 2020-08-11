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

#import "FirebaseInAppMessaging/Sources/Private/Flows/FIRIAMActivityLogger.h"
#import "FirebaseInAppMessaging/Sources/Private/Flows/FIRIAMBookKeeper.h"
#import "FirebaseInAppMessaging/Sources/Private/Flows/FIRIAMDisplayExecutor.h"
#import "FirebaseInAppMessaging/Sources/Private/Flows/FIRIAMMessageClientCache.h"
#import "FirebaseInAppMessaging/Sources/Private/Flows/FIRIAMServerMsgFetchStorage.h"
#import "FirebaseInAppMessaging/Sources/Private/Runtime/FIRIAMSDKSettings.h"

NS_ASSUME_NONNULL_BEGIN
// A class for managing the objects/dependencies for supporting different fiam flows at runtime
@interface FIRIAMRuntimeManager : NSObject
@property(nonatomic, nonnull) FIRIAMSDKSettings *currentSetting;
@property(nonatomic, nonnull) FIRIAMActivityLogger *activityLogger;
@property(nonatomic, nonnull) FIRIAMBookKeeperViaUserDefaults *bookKeeper;
@property(nonatomic, nonnull) FIRIAMMessageClientCache *messageCache;
@property(nonatomic, nonnull) FIRIAMServerMsgFetchStorage *fetchResultStorage;
@property(nonatomic, nonnull) FIRIAMDisplayExecutor *displayExecutor;

// Initialize fiam SDKs and start various flows with specified settings.
- (void)startRuntimeWithSDKSettings:(FIRIAMSDKSettings *)settings;

// Pause runtime flows/functions to disable SDK functions at runtime
- (void)pause;

// Resume runtime flows/functions.
- (void)resume;

// allows app to programmatically turn on/off auto data collection for fiam, which also implies
// running/stopping fiam functionalities
@property(nonatomic) BOOL automaticDataCollectionEnabled;

// Get the global singleton instance
+ (FIRIAMRuntimeManager *)getSDKRuntimeInstance;

// a method used to suppress or allow message being displayed based on the parameter
// @param shouldSuppress if true, no new message is rendered by the sdk.
- (void)setShouldSuppressMessageDisplay:(BOOL)shouldSuppress;
@end
NS_ASSUME_NONNULL_END
