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
#import "Crashlytics/Crashlytics/Models/FIRCLSFileManager.h"
#import "Crashlytics/Crashlytics/Models/FIRCLSOnDemandModel.h"
#import "Crashlytics/Crashlytics/Private/FIRCLSOnDemandModel_Private.h"

#include <math.h>

@interface FIRCLSOnDemandModel ()

@property(nonatomic, readonly) int recordedOnDemandExceptionCount;
@property(nonatomic, readonly) int droppedOnDemandExceptionCount;
@property(nonatomic, readonly) int queuedOperationsCount;

@property(nonatomic, strong) FIRCLSSettings *settings;
@property(nonatomic, strong) NSOperationQueue *operationQueue;
@property(nonatomic, strong) dispatch_queue_t dispatchQueue;

@property(nonatomic) double lastUpdated;
@property(nonatomic) double currentStep;

@property(nonatomic, strong) FIRCLSFileManager *fileManager;
@property(nonatomic, strong) NSMutableArray *storedActiveReportPaths;

@end

@implementation FIRCLSOnDemandModel

@synthesize recordedOnDemandExceptionCount = _recordedOnDemandExceptionCount;
@synthesize droppedOnDemandExceptionCount = _droppedOnDemandExceptionCount;
@synthesize queuedOperationsCount = _queuedOperationsCount;

static const double MAX_DELAY_SEC = 3600;
static const double SEC_PER_MINUTE = 60;

- (instancetype)initWithFIRCLSSettings:(FIRCLSSettings *)settings
                           fileManager:(FIRCLSFileManager *)fileManager {
  self = [super init];
  if (!self) {
    return nil;
  }

  _settings = settings;
  _fileManager = fileManager;

  NSString *sdkBundleID = FIRCLSApplicationGetSDKBundleID();
  _operationQueue = [NSOperationQueue new];
  [_operationQueue setMaxConcurrentOperationCount:1];
  [_operationQueue setName:[sdkBundleID stringByAppendingString:@".on-demand-queue"]];
  _dispatchQueue = dispatch_queue_create("com.google.firebase.crashlytics.on.demand", 0);
  _operationQueue.underlyingQueue = _dispatchQueue;

  _queuedOperationsCount = 0;

  _recordedOnDemandExceptionCount = 0;
  _droppedOnDemandExceptionCount = 0;

  _lastUpdated = [NSDate timeIntervalSinceReferenceDate];
  _currentStep = -1;

  self.storedActiveReportPaths = [NSMutableArray array];

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
  // log the occurrence but drop the event.
  @synchronized(self) {
    if ([self isQueueFull]) {
      FIRCLSDebugLog(@"No available on-demand quota, dropping report");
      [self incrementDroppedExceptionCount];
      [self incrementRecordedExceptionCount];
      return NO;  // Didn't record or submit the exception because no quota was available.
    }

    FIRCLSDataCollectionToken *dataCollectionToken = [FIRCLSDataCollectionToken validToken];
    NSString *activeReportPath = [self recordOnDemandExceptionWithModel:exceptionModel];

    if (!activeReportPath) {
      FIRCLSErrorLog(@"Error recording on-demand exception");
      return NO;  // Something went wrong when recording the exception, so we don't have a valid
                  // path.
    }

    // Only submit an exception report if data collection is enabled. Otherwise, the report
    // is stored until send or delete unsent reports is called.
    [self incrementQueuedOperationCount];
    [self incrementRecordedExceptionCount];
    [self resetDroppedExceptionCount];

    [self.operationQueue addOperationWithBlock:^{
      double uploadDelay = [self calculateUploadDelay];

      if (dataCollectionEnabled) {
        [existingReportManager handleOnDemandReportUpload:activeReportPath
                                      dataCollectionToken:dataCollectionToken
                                                 asUrgent:YES];
        FIRCLSDebugLog(@"Submitted an on-demand exception, starting delay %.20f", uploadDelay);
      } else {
        [self.storedActiveReportPaths insertObject:activeReportPath atIndex:0];
        if ([self.storedActiveReportPaths count] > FIRCLSMaxUnsentReports) {
          [self.fileManager removeItemAtPath:[self.storedActiveReportPaths lastObject]];
          [self.storedActiveReportPaths removeLastObject];
          [self decrementRecordedExceptionCount];
          [self incrementDroppedExceptionCount];
        }
        FIRCLSDebugLog(@"Stored an on-demand exception, starting delay %.20f", uploadDelay);
      }
      [self implementOnDemandUploadDelay:uploadDelay];
      [self decrementQueuedOperationCount];
    }];
    return YES;  // Recorded and submitted the exception.
  }
}

- (double)calculateUploadDelay {
  double calculatedStepDuration = [self calculateStepDuration];
  double power = pow(self.settings.onDemandBackoffBase, calculatedStepDuration);
  NSNumber *calculatedUploadDelay =
      [NSNumber numberWithDouble:(SEC_PER_MINUTE / self.settings.onDemandUploadRate) * power];
  NSComparisonResult result =
      [[NSNumber numberWithDouble:MAX_DELAY_SEC] compare:calculatedUploadDelay];
  return (result == NSOrderedAscending) ? MAX_DELAY_SEC : [calculatedUploadDelay doubleValue];
}

- (double)calculateStepDuration {
  double currentTime = [NSDate timeIntervalSinceReferenceDate];
  BOOL queueIsFull = [self isQueueFull];

  if (self.currentStep == -1) {
    self.currentStep = 0;
    self.lastUpdated = currentTime;
  }

  double delta =
      (currentTime - self.lastUpdated) / (double)self.settings.onDemandBackoffStepDuration;
  double queueFullDuration = (self.currentStep + delta) > 100 ? 100 : (self.currentStep + delta);
  double queueNotFullDuration = (self.currentStep - delta) < 0 ? 0 : (self.currentStep - delta);
  double calculatedDuration = queueIsFull ? queueFullDuration : queueNotFullDuration;

  if (self.currentStep != calculatedDuration) {
    self.currentStep = calculatedDuration;
    self.lastUpdated = currentTime;
  }

  return calculatedDuration;
}

- (void)implementOnDemandUploadDelay:(int)delay {
  sleep(delay);
}

- (NSString *)recordOnDemandExceptionWithModel:(FIRExceptionModel *)exceptionModel {
  return FIRCLSExceptionRecordOnDemandModel(exceptionModel, self.recordedOnDemandExceptionCount,
                                            self.droppedOnDemandExceptionCount);
}

- (int)droppedOnDemandExceptionCount {
  @synchronized(self) {
    return _droppedOnDemandExceptionCount;
  }
}

- (void)setDroppedOnDemandExceptionCount:(int)count {
  @synchronized(self) {
    _droppedOnDemandExceptionCount = count;
  }
}

- (void)incrementDroppedExceptionCount {
  @synchronized(self) {
    [self setDroppedOnDemandExceptionCount:[self droppedOnDemandExceptionCount] + 1];
  }
}

- (void)decrementDroppedExceptionCount {
  @synchronized(self) {
    [self setDroppedOnDemandExceptionCount:[self droppedOnDemandExceptionCount] - 1];
  }
}

- (void)resetDroppedExceptionCount {
  @synchronized(self) {
    [self setDroppedOnDemandExceptionCount:0];
  }
}

- (int)recordedOnDemandExceptionCount {
  @synchronized(self) {
    return _recordedOnDemandExceptionCount;
  }
}

- (void)setRecordedOnDemandExceptionCount:(int)count {
  @synchronized(self) {
    _recordedOnDemandExceptionCount = count;
  }
}

- (void)incrementRecordedExceptionCount {
  @synchronized(self) {
    [self setRecordedOnDemandExceptionCount:[self recordedOnDemandExceptionCount] + 1];
  }
}

- (void)decrementRecordedExceptionCount {
  @synchronized(self) {
    [self setRecordedOnDemandExceptionCount:[self recordedOnDemandExceptionCount] - 1];
  }
}

- (int)getQueuedOperationsCount {
  @synchronized(self) {
    return _queuedOperationsCount;
  }
}

- (void)setQueuedOperationsCount:(int)count {
  @synchronized(self) {
    _queuedOperationsCount = count;
  }
}

- (void)incrementQueuedOperationCount {
  @synchronized(self) {
    [self setQueuedOperationsCount:[self getQueuedOperationsCount] + 1];
  }
}

- (void)decrementQueuedOperationCount {
  @synchronized(self) {
    [self setQueuedOperationsCount:[self getQueuedOperationsCount] - 1];
  }
}

- (BOOL)isQueueFull {
  return ([self getQueuedOperationsCount] >= self.settings.onDemandUploadRate);
}

@end
