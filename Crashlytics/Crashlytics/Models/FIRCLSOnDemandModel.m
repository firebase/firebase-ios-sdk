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

#import <Foundation/Foundation.h>

#import "Crashlytics/Crashlytics/Components/FIRCLSApplication.h"
#import "Crashlytics/Crashlytics/DataCollection/FIRCLSDataCollectionArbiter.h"
#import "Crashlytics/Crashlytics/DataCollection/FIRCLSDataCollectionToken.h"
#import "Crashlytics/Crashlytics/Handlers/FIRCLSException.h"
#import "Crashlytics/Crashlytics/Helpers/FIRCLSLogger.h"
#include "Crashlytics/Crashlytics/Helpers/FIRCLSUtility.h"
#import "Crashlytics/Crashlytics/Models/FIRCLSOnDemandModel.h"
#import "Crashlytics/Crashlytics/Private/FIRCLSOnDemandModel_Private.h"

#include <math.h>

@interface FIRCLSOnDemandModel ()

@property(nonatomic, readonly) int recordedOnDemandExceptionCount;
@property(nonatomic, readonly) int droppedOnDemandExceptionCount;

@property(nonatomic, readonly) uint32_t uploadRate;
@property(nonatomic, readonly) double base;
@property(nonatomic, readonly) uint32_t stepDuration;

@property(nonatomic, strong) NSOperationQueue *operationQueue;
@property(nonatomic, strong) dispatch_queue_t dispatchQueue;
@property(nonatomic) int queuedOperationsCount;

@property(nonatomic) double lastUpdated;
@property(nonatomic) double currentStep;

@end

@implementation FIRCLSOnDemandModel

static const double MAX_DELAY_SEC = 3600;
static const double SEC_PER_MINUTE = 60;

- (instancetype)initWithOnDemandUploadRate:(int)uploadRate
                                      base:(double)base
                              stepDuration:(int)stepDuration {
  self = [super init];
  if (!self) {
    return nil;
  }

  _uploadRate = uploadRate;
  _base = base;
  _stepDuration = stepDuration;

  _operationQueue = [NSOperationQueue new];
  [_operationQueue setMaxConcurrentOperationCount:1];
  [_operationQueue
      setName:[FIRCLSApplicationGetSDKBundleID() stringByAppendingString:@".on-demand-queue"]];
  _dispatchQueue = dispatch_queue_create("com.google.firebase.crashlytics.on.demand", 0);
  _operationQueue.underlyingQueue = _dispatchQueue;
  _queuedOperationsCount = 0;

  _recordedOnDemandExceptionCount = 0;
  _droppedOnDemandExceptionCount = 0;

  _lastUpdated = [NSDate timeIntervalSinceReferenceDate];
  _currentStep = -1;

  return self;
}

/*
 * Called from FIRCrashlytics whenever the on-demand record exception method is called. Handles
 * rate limiting and exponential backoff.
 */
- (BOOL)recordOnDemandExceptionIfQuota:(FIRExceptionModel *)exceptionModel
             withDataCollectionEnabled:(BOOL)dataCollectionEnabled
            usingExistingReportManager:(FIRCLSExistingReportManager *)existingReportManager {
  // Record the exception model into a new report if there is unused on-demand quota. Otherwise,
  // log the occurence but drop the event.
  @synchronized(self) {
    if (![self isQueueFull]) {
      FIRCLSDataCollectionToken *dataCollectionToken = [FIRCLSDataCollectionToken validToken];
      NSString *activeReportPath = FIRCLSExceptionRecordOnDemandModel(
          exceptionModel, self.recordedOnDemandExceptionCount, self.droppedOnDemandExceptionCount);

      // Only submit an exception report if data collection is enabled. Otherwise, the report
      // is stored until send or delete unsent reports is called.
      if (dataCollectionEnabled) {
        if (activeReportPath) {
          [self incrementQueuedOperationCount:1];
          [self getOrIncrementOnDemandEventCountForCurrentRun:YES];
          dispatch_async(self.dispatchQueue, ^{
            [existingReportManager handleOnDemandReportUpload:activeReportPath
                                          dataCollectionToken:dataCollectionToken
                                                     asUrgent:YES];
            double uploadDelay = [self calculateUploadDelay];
            FIRCLSInfoLog(@"Submitted an on-demand exception, starting delay %.20f", uploadDelay);
            sleep(uploadDelay);
          });
          return YES;  // Recorded and submitted the exception.
        } else {
          FIRCLSInfoLog(@"Error recording on-demand exception");
          return NO;  // Something went wrong when recording the exception, so we don't have a valid
                      // path.
        }
      }
      // TODO: should we update delay if data collection is off?
      // TODO: should we update counter(s)?
      //      FIRCLSInfoLog(@"Submitted an on-demand exception with delay %d", uploadDelay);
      //      [self updateBucketsAndCountWithDelay:uploadDelay];
      return YES;  // Recorded exception but did not submit since data collection is disabled.
    } else {
      FIRCLSInfoLog(@"No available on-demand quota. Dropping report.");
      [self getOrIncrementDroppedOnDemandEventCountForCurrentRun:YES];
      return NO;  // Didn't record or submit the exception because no quota was available.
    }
  }
}

// Helper methods

- (double)calculateUploadDelay {
  double calculatedStepDuration = [self calculateStepDuration];
  double power = pow(self.base, calculatedStepDuration);
  NSNumber *calculatedUploadDelay =
      [NSNumber numberWithDouble:(SEC_PER_MINUTE / self.uploadRate) * power];
  NSComparisonResult result =
      [[NSNumber numberWithDouble:MAX_DELAY_SEC] compare:calculatedUploadDelay];
  [self incrementQueuedOperationCount:-1];
  return (result == NSOrderedAscending) ? MAX_DELAY_SEC : [calculatedUploadDelay doubleValue];
}

- (double)calculateStepDuration {
  double currentTime = [NSDate timeIntervalSinceReferenceDate];
  BOOL queueIsFull = [self isQueueFull];

  if (self.currentStep == -1) {
    self.currentStep = 0;
    self.lastUpdated = currentTime;
  }

  double delta = (currentTime - self.lastUpdated) / (double)self.stepDuration;
  double queueFullDuration = (self.currentStep + delta) > 100 ? 100 : (self.currentStep + delta);
  double queueNotFullDuration = (self.currentStep - delta) < 0 ? 0 : (self.currentStep - delta);
  double calculatedDuration = queueIsFull ? queueFullDuration : queueNotFullDuration;

  if (self.currentStep != calculatedDuration) {
    self.currentStep = calculatedDuration;
    self.lastUpdated = currentTime;
  }

  return calculatedDuration;
}

- (NSInteger)getOrIncrementOnDemandEventCountForCurrentRun:(BOOL)increment {
  @synchronized(self) {
    if (increment) {
      _recordedOnDemandExceptionCount += 1;
    }
    return self.recordedOnDemandExceptionCount;
  }
}

- (NSInteger)getOrIncrementDroppedOnDemandEventCountForCurrentRun:(BOOL)increment {
  @synchronized(self) {
    if (increment) {
      _droppedOnDemandExceptionCount += 1;
    }
    return self.droppedOnDemandExceptionCount;
  }
}

- (int)incrementQueuedOperationCount:(int)increment {
  @synchronized(self) {
    _queuedOperationsCount += increment;
    return self.queuedOperationsCount;
  }
}

- (int)getQueuedOperationsCount {
  return [self incrementQueuedOperationCount:0];
}

- (void)setQueuedOperationsCount:(int)queuedOperations {
  [self incrementQueuedOperationCount:queuedOperations];
}

- (BOOL)isQueueFull {
  return [self incrementQueuedOperationCount:0] >= self.uploadRate;
  ;
}

@end
