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

#import "Crashlytics/UnitTests/Mocks/FIRCLSMockMetricKitManager.h"
#import "Crashlytics/Crashlytics/Controllers/FIRCLSManagerData.h"
#import "Crashlytics/Crashlytics/Models/FIRCLSFileManager.h"
#import "Crashlytics/UnitTests/Mocks/FIRCLSMockExistingReportManager.h"

#if CLS_METRICKIT_SUPPORTED

@interface FIRCLSMockMetricKitManager ()

@property FBLPromise *metricKitDataAvailable;
@property FIRCLSExistingReportManager *existingReportManager;
@property FIRCLSFileManager *fileManager;
@property FIRCLSManagerData *managerData;
@property BOOL metricKitPromiseFulfilled;

@end

@implementation FIRCLSMockMetricKitManager

- (instancetype)initWithManagerData:(FIRCLSManagerData *)managerData
              existingReportManager:(FIRCLSExistingReportManager *)existingReportManager
                        fileManager:(FIRCLSFileManager *)fileManager {
  self = [super initWithManagerData:managerData
              existingReportManager:existingReportManager
                        fileManager:fileManager];
  _existingReportManager = existingReportManager;
  _fileManager = fileManager;
  _managerData = managerData;
  _metricKitPromiseFulfilled = NO;
  return self;
}

// This mock skips the normal flow of resolving the metricKitDataAvailable promise if there are no
// fatal reports available on the device but otherwise registers as normal.
- (void)registerMetricKitManager API_AVAILABLE(ios(14)) {
  [[MXMetricManager sharedManager] addSubscriber:self];
  self.metricKitDataAvailable = [FBLPromise pendingPromise];

  // If we haven't resolved this promise within three seconds, resolve it now so that we're not
  // waiting indefinitely for MetricKit payloads that won't arrive.
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), self.managerData.dispatchQueue,
                 ^{
                   @synchronized(self) {
                     if (!self.metricKitPromiseFulfilled) {
                       [self.metricKitDataAvailable fulfill:nil];
                       self.metricKitPromiseFulfilled = YES;
                     }
                   }
                 });
}

@end
#endif
