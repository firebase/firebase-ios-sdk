// Copyright 2020 Google LLC
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

#import "FirebasePerformance/Sources/FPRClient.h"
#import "FirebasePerformance/Sources/Protogen/nanopb/perf_metric.nanopb.h"

@class FPRGDTLogger;
@class FPRConfigurations;
@class FIRInstallations;

/// Protocol to define the Firebase performance provider for the component framework.
@protocol FIRPerformanceProvider <NSObject>

@end

/**
 * Extension that is added on top of the class FPRClient to make the private properties visible
 * between the implementation file and the unit tests.
 */
@interface FPRClient ()

@property(nonatomic, getter=isConfigured, readwrite) BOOL configured;

/** GDT Logger to transmit Fireperf events to Google Data Transport. */
@property(nonatomic) FPRGDTLogger *gdtLogger;

/** The queue group all FPRClient work will run on. Used for testing only. */
@property(nonatomic, readonly) dispatch_group_t eventsQueueGroup;

/** Serial queue used for processing events. */
@property(nonatomic, readonly) dispatch_queue_t eventsQueue;

/** Firebase Remote Configuration object for FPRClient. */
@property(nonatomic) FPRConfigurations *configuration;

/** Firebase Installations object for FPRClient. */
@property(nonatomic) FIRInstallations *installations;

/** The Firebase Project ID of the project. */
@property(nonatomic, readonly) NSString *projectID;

/** The bundle ID of the project*/
@property(nonatomic, readonly) NSString *bundleID;
/**
 * Determines the log directory path in the caches directory.
 *
 * @return The directory in which Clearcut logs are stored.
 */
+ (NSString *)logDirectoryPath;

/**
 * Cleans up the log directory path in the cache directory created for Clearcut logs storage.
 *
 * @remark This method (cleanup logic) should stay for a while until all of our apps have migrated
 * to a version which includes this logic.
 */
+ (void)cleanupClearcutCacheDirectory;

/** Performs post processing and logs a firebase_perf_v1_PerfMetric object to Google Data Transport.
 *  @param event Reference to a firebase_perf_v1_PerfMetric proto object.
 */
- (void)processAndLogEvent:(firebase_perf_v1_PerfMetric)event;

@end
