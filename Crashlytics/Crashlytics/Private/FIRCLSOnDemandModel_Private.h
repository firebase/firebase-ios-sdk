// Copyright 2022 Google LLC
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

#ifndef FIRCLSOnDemandModel_Private_h
#define FIRCLSOnDemandModel_Private_h

#import <Foundation/Foundation.h>

#import "Crashlytics/Crashlytics/Models/FIRCLSOnDemandModel.h"
#import "Crashlytics/Crashlytics/Models/FIRCLSSettings.h"
#import "Crashlytics/Crashlytics/Private/FIRCLSExistingReportManager_Private.h"
#import "Crashlytics/Crashlytics/Private/FIRExceptionModel_Private.h"

@interface FIRCLSOnDemandModel (Private)

- (instancetype)initWithFIRCLSSettings:(FIRCLSSettings *)settings;

- (BOOL)recordOnDemandExceptionIfQuota:(FIRExceptionModel *)exceptionModel
             withDataCollectionEnabled:(BOOL)dataCollectionEnabled
            usingExistingReportManager:(FIRCLSExistingReportManager *)existingReportManager;

- (int)getQueuedOperationsCount;
- (void)setQueuedOperationsCount:(int)count;

// When data collection is off, stores active paths that have been recorded but not dispatched for
// upload. Kept sorted (newest at front) so that we can limit on-device reports to the newest
// `FIRCLSMaxUnsentReports` reports.
@property(nonatomic, strong) NSMutableArray *storedActiveReportPaths;

@property(nonatomic, readonly) int recordedOnDemandExceptionCount;
@property(nonatomic, readonly) int droppedOnDemandExceptionCount;
@property(nonatomic, readonly) int queuedOperationsCount;

@property(nonatomic, strong) NSOperationQueue *operationQueue;

@end

#endif /* FIRCLSOnDemandModel_Private_h */
