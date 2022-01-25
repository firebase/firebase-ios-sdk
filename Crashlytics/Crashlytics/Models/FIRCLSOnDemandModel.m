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

#import "Crashlytics/Crashlytics/DataCollection/FIRCLSDataCollectionArbiter.h"
#import "Crashlytics/Crashlytics/DataCollection/FIRCLSDataCollectionToken.h"
#import "Crashlytics/Crashlytics/Handlers/FIRCLSException.h"
#import "Crashlytics/Crashlytics/Helpers/FIRCLSLogger.h"
#include "Crashlytics/Crashlytics/Helpers/FIRCLSUtility.h"
#import "Crashlytics/Crashlytics/Models/FIRCLSOnDemandModel.h"
#import "Crashlytics/Crashlytics/Private/FIRCLSOnDemandModel_Private.h"

#include <math.h>

@interface FIRCLSOnDemandModel ()

@property(nonatomic) int recordedOnDemandExceptionCount;
@property(nonatomic) int droppedOnDemandExceptionCount;

@property(nonatomic, readonly) uint32_t uploadRate;
@property(nonatomic, readonly) double baseExponent;
@property(nonatomic, readonly) uint32_t stepDuration;

@property(nonatomic) double lastUpdated;
@property(nonatomic) double currentStep;

@property(nonatomic, copy) NSMutableArray *buckets;

@end

@implementation FIRCLSOnDemandModel

// There should only ever be one onDemandModel per run of the app.
static FIRCLSOnDemandModel *sharedOnDemandModel = nil;
static const double MAX_DELAY_SEC = 3600;
static const double SEC_PER_MINUTE = 60;

- (instancetype)initWithOnDemandUploadRate:(int)uploadRate
                              baseExponent:(double)baseExponent
                              stepDuration:(int)stepDuration {
  if (sharedOnDemandModel) {
    return sharedOnDemandModel;
  }

  self = [super init];
  if (!self) {
    return nil;
  }

  _uploadRate = uploadRate;
  _baseExponent = baseExponent;
  _stepDuration = stepDuration;

  _recordedOnDemandExceptionCount = 0;

  _buckets = [NSMutableArray array];
  _lastUpdated = [NSDate timeIntervalSinceReferenceDate];
  _currentStep = -1;

  for (int i = 0; i < uploadRate; i++) {
    [_buckets addObject:[NSNumber numberWithInt:-1]];
  }
  sharedOnDemandModel = self;
  return sharedOnDemandModel;
}

/*
 * Called from FIRCrashlytics whenever the on-demand record exception method is called.
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
      double uploadDelay = [self calculateUploadDelay:YES];
      if (dataCollectionEnabled) {
        if (activeReportPath) {
          // dispatch after calculateUploadDelay then update bucket with time of upload
          [existingReportManager handleOnDemandReportUpload:activeReportPath
                                        dataCollectionToken:dataCollectionToken
                                                  withDelay:uploadDelay
                                                   asUrgent:YES];
          FIRCLSInfoLog(@"Submitted an on-demand exception with delay %.20f", uploadDelay);
          [self updateBucketsAndCountWithDelay:uploadDelay];
          return YES;  // Recorded and submitted the exception.
        } else {
          FIRCLSInfoLog(@"Error recording on-demand exception");
          return NO;  // Something went wrong when recording the exception, so we don't have a valid
                      // path.
        }
      }
      FIRCLSInfoLog(@"Submitted an on-demand exception with delay %d", uploadDelay);
      [self updateBucketsAndCountWithDelay:uploadDelay];
      return YES;  // Recorded exception but did not submit since data collection is disabled.
    } else {
      FIRCLSInfoLog(@"No available on-demand quota. Dropping report.");
      self.droppedOnDemandExceptionCount++;
      [self calculateUploadDelay:YES];
      return NO;  // Didn't record or submit then exception because no quota was available.
    }
  }
}

// Helper methods

- (double)calculateUploadDelay:(BOOL)shouldUpdate {
  // TODO: should return 0 if queue is empty?

  double calculatedStepDuration = [self calculateStepDuration:shouldUpdate];
  double power = pow(self.baseExponent, calculatedStepDuration);
  NSNumber *calculatedUploadDelay =
      [NSNumber numberWithDouble:(SEC_PER_MINUTE / self.uploadRate) * power];
  NSComparisonResult result =
      [[NSNumber numberWithDouble:MAX_DELAY_SEC] compare:calculatedUploadDelay];
  return (result == NSOrderedAscending) ? MAX_DELAY_SEC : [calculatedUploadDelay doubleValue];
}

- (double)calculateStepDuration:(BOOL)shouldUpdate {
  double currentTime = [NSDate timeIntervalSinceReferenceDate];
  double delta = (currentTime - self.lastUpdated) / (double)self.stepDuration;
  double queueFullDuration = (self.currentStep + delta) > 100 ? 100 : (self.currentStep + delta);
  double queueNotFullDuration = (self.currentStep - delta) < 0 ? 0 : (self.currentStep - delta);
  double calculatedDuration = [self isQueueFull] ? queueFullDuration : queueNotFullDuration;

  if (shouldUpdate && self.currentStep != calculatedDuration) {
    self.currentStep = calculatedDuration;
    self.lastUpdated = currentTime;
  }
  return calculatedDuration;
}

- (NSInteger)getOnDemandEventCountForCurrentRun {
  @synchronized(self) {
    return self.recordedOnDemandExceptionCount;
  }
}

- (NSInteger)getDroppedOnDemandEventCountForCurrentRun {
  @synchronized(self) {
    return self.droppedOnDemandExceptionCount;
  }
}

// A bucket is "expired" if it represents an event that has already been sent.
- (BOOL)isExpiredBucket:(NSNumber *)bucket {
  NSTimeInterval currentTimestamp = [NSDate timeIntervalSinceReferenceDate];
  return bucket.intValue < currentTimestamp;
}

- (BOOL)isQueueFull {
  BOOL result = YES;
  for (NSNumber *bucket in self.buckets) {
    if ([self isExpiredBucket:bucket]) {
      result = NO;
      break;
    }
  }
  return result;
}

- (void)updateBucketsAndCountWithDelay:(double)uploadDelay {
  for (int i = 0; i < self.uploadRate; i++) {
    NSNumber *bucket = self.buckets[i];
    if ([self isExpiredBucket:bucket]) {
      self.recordedOnDemandExceptionCount += 1;
      self.buckets[i] =
          [NSNumber numberWithDouble:[NSDate timeIntervalSinceReferenceDate] + uploadDelay];
      break;
    }
  }
}

@end
