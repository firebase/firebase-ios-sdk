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

#import "Crashlytics/Crashlytics/Public/FirebaseCrashlytics/FIRCLSOnDemandModel.h"

@interface FIRCLSOnDemandModel ()

@property(nonatomic) NSInteger onDemandExceptionCount;

@property(nonatomic) uint32_t uploadRate;
@property(nonatomic) uint32_t baseExponent;
@property(nonatomic) uint32_t stepDuration;

@property(nonatomic, copy) NSArray<NSInteger> *buckets;

@end

@implementation FIRCLSOnDemandModel

- (instancetype)initWithOnDemandUploadRate:(int)uploadRate baseExponent:(int)baseExponent stepDuration:(int)stepDuration {
  
  self = [super init];
  if (!self) {
    return nil;
  }
  
  _uploadRate = uploadRate;
  _baseExponent = baseExponent;
  _stepDuration = stepDuration;
  
}

- (int)getOnDemandEventCountForCurrentRun {
  return onDemandExceptionCount;
}



- (BOOL)canRecordOnDemandException {
  // we can record an exception if there is space in the bucket
  NSTimeInterval currentTimestamp = [NSDate timeIntervalSinceReferenceDate];

//  for (NSInteger bucket in buckets) {
//    if (bucket + uploadRate < currentTimestamp) {
//
//    }
//  }
  return YES;
}

- (void)onDemandExceptionRecorded {
  // set open bucket to current timestamp
  onDemandExceptionCount += 1;
}

@end
