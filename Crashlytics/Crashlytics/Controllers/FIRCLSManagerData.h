// Copyright 2021 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class FIRCLSFileManager;
@class FIRInstallations;
@class FIRCLSDataCollectionArbiter;
@class FIRCLSApplicationIdentifierModel;
@class FIRCLSInstallIdentifierModel;
@class FIRCLSExecutionIdentifierModel;
@class FIRCLSSettings;
@class FIRCLSLaunchMarkerModel;
@class GDTCORTransport;
@protocol FIRAnalyticsInterop;

/*
 * FIRCLSManagerData's purpose is to simplify the adding and removing of
 * dependencies from each of the Manager classes so that it's easier
 * to inject mock classes during testing. A lot of the Manager classes
 * share these dependencies, but don't use all of them.
 *
 * If you plan on adding interdependencies between Managers, do not add a pointer
 * to the dependency here. Instead add them as a new value to the constructor of
 * the Manager, and construct them in FirebaseCrashlytics. This data structure should
 * be for Models and other SDKs / Interops Crashlytics depends on.
 */
@interface FIRCLSManagerData : NSObject

- (instancetype)initWithGoogleAppID:(NSString *)googleAppID
                    googleTransport:(GDTCORTransport *)googleTransport
                      installations:(FIRInstallations *)installations
                          analytics:(nullable id<FIRAnalyticsInterop>)analytics
                        fileManager:(FIRCLSFileManager *)fileManager
                        dataArbiter:(FIRCLSDataCollectionArbiter *)dataArbiter
                           settings:(FIRCLSSettings *)settings NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@property(nonatomic, readonly) NSString *googleAppID;

@property(nonatomic, strong) GDTCORTransport *googleTransport;

@property(nonatomic, strong) FIRInstallations *installations;

@property(nonatomic, strong) id<FIRAnalyticsInterop> analytics;

@property(nonatomic, strong) FIRCLSFileManager *fileManager;

@property(nonatomic, strong) FIRCLSDataCollectionArbiter *dataArbiter;

// Uniquely identifies a build / binary of the app
@property(nonatomic, strong) FIRCLSApplicationIdentifierModel *appIDModel;

// Uniquely identifies an install of the app
@property(nonatomic, strong) FIRCLSInstallIdentifierModel *installIDModel;

// Uniquely identifies a run of the app
@property(nonatomic, strong) FIRCLSExecutionIdentifierModel *executionIDModel;

// Settings fetched from the server
@property(nonatomic, strong) FIRCLSSettings *settings;

// These queues function together as a single startup queue
@property(nonatomic, strong) NSOperationQueue *operationQueue;
@property(nonatomic, strong) dispatch_queue_t dispatchQueue;

@end

NS_ASSUME_NONNULL_END
