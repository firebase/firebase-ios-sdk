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

#import "Crashlytics/Crashlytics/Controllers/FIRCLSExistingReportManager.h"

#import "Crashlytics/Crashlytics/Controllers/FIRCLSManagerData.h"
#import "Crashlytics/Crashlytics/Controllers/FIRCLSReportUploader.h"
#import "Crashlytics/Crashlytics/DataCollection/FIRCLSDataCollectionToken.h"
#import "Crashlytics/Crashlytics/Helpers/FIRCLSLogger.h"
#import "Crashlytics/Crashlytics/Models/FIRCLSFileManager.h"
#import "Crashlytics/Crashlytics/Models/FIRCLSInternalReport.h"
#import "Crashlytics/Crashlytics/Private/FIRCrashlyticsReport_Private.h"
#import "Crashlytics/Crashlytics/Public/FirebaseCrashlytics/FIRCrashlyticsReport.h"

// This value should stay in sync with the Android SDK
NSUInteger const FIRCLSMaxUnsentReports = 4;

@interface FIRCLSExistingReportManager ()

@property(nonatomic, strong) FIRCLSFileManager *fileManager;
@property(nonatomic, strong) FIRCLSReportUploader *reportUploader;
@property(nonatomic, strong) NSOperationQueue *operationQueue;

// This list of active reports excludes the brand new active report that will be created this run of
// the app.
@property(nonatomic, strong) NSArray *existingUnemptyActiveReportPaths;
@property(nonatomic, strong) NSArray *processingReportPaths;
@property(nonatomic, strong) NSArray *preparedReportPaths;

@property(nonatomic, strong) FIRCLSInternalReport *newestInternalReport;

@end

@implementation FIRCLSExistingReportManager

- (instancetype)initWithManagerData:(FIRCLSManagerData *)managerData
                     reportUploader:(FIRCLSReportUploader *)reportUploader {
  self = [super init];
  if (!self) {
    return nil;
  }

  _fileManager = managerData.fileManager;
  _operationQueue = managerData.operationQueue;
  _reportUploader = reportUploader;

  return self;
}

NSInteger compareNewer(FIRCLSInternalReport *reportA,
                       FIRCLSInternalReport *reportB,
                       void *context) {
  // Compare naturally sorts with oldest first, so swap A and B
  return [reportB.dateCreated compare:reportA.dateCreated];
}

- (void)collectExistingReports {
  self.existingUnemptyActiveReportPaths =
      [self getUnsentActiveReportsAndDeleteEmptyOrOld:self.fileManager.activePathContents];
  self.processingReportPaths = self.fileManager.processingPathContents;
  self.preparedReportPaths = self.fileManager.preparedPathContents;
}

- (FIRCrashlyticsReport *)newestUnsentReport {
  if (self.unsentReportsCount <= 0) {
    return nil;
  }

  return [[FIRCrashlyticsReport alloc] initWithInternalReport:self.newestInternalReport];
}

- (NSUInteger)unsentReportsCount {
  // There are nuances about why we only count active reports.
  // See the header comment for more information.
  return self.existingUnemptyActiveReportPaths.count;
}

/*
 * This has the side effect of deleting any reports over the max, starting with oldest reports.
 */
- (NSArray<NSString *> *)getUnsentActiveReportsAndDeleteEmptyOrOld:(NSArray *)reportPaths {
  NSMutableArray<FIRCLSInternalReport *> *validReports = [NSMutableArray array];
  for (NSString *path in reportPaths) {
    FIRCLSInternalReport *_Nullable report = [FIRCLSInternalReport reportWithPath:path];
    if (!report) {
      continue;
    }

    // Delete reports without any crashes or non-fatals
    if (![report hasAnyEvents]) {
      [self.operationQueue addOperationWithBlock:^{
        [self.fileManager removeItemAtPath:path];
      }];
      continue;
    }

    [validReports addObject:report];
  }

  if (validReports.count == 0) {
    return @[];
  }

  // Sort with the newest at the end
  [validReports sortUsingFunction:compareNewer context:nil];

  // Set our report for updating in checkAndUpdateUnsentReports
  self.newestInternalReport = [validReports firstObject];

  // Delete any reports above the limit, starting with the oldest
  // which should be at the start of the array.
  if (validReports.count > FIRCLSMaxUnsentReports) {
    NSUInteger deletingCount = validReports.count - FIRCLSMaxUnsentReports;
    FIRCLSInfoLog(@"Deleting %lu unsent reports over the limit of %lu to prevent disk space from "
                  @"filling up. To prevent this make sure to call send/deleteUnsentReports.",
                  deletingCount, FIRCLSMaxUnsentReports);
  }

  // Not that validReports is sorted, delete any reports at indices > MAX_UNSENT_REPORTS, and
  // collect the rest of the reports to return.
  NSMutableArray<NSString *> *validReportPaths = [NSMutableArray array];
  for (int i = 0; i < validReports.count; i++) {
    if (i >= FIRCLSMaxUnsentReports) {
      [self.operationQueue addOperationWithBlock:^{
        NSString *path = [[validReports objectAtIndex:i] path];
        [self.fileManager removeItemAtPath:path];
      }];
    } else {
      [validReportPaths addObject:[[validReports objectAtIndex:i] path]];
    }
  }

  return validReportPaths;
}

- (void)sendUnsentReportsWithToken:(FIRCLSDataCollectionToken *)dataCollectionToken
                          asUrgent:(BOOL)urgent {
  for (NSString *path in self.existingUnemptyActiveReportPaths) {
    [self processExistingActiveReportPath:path
                      dataCollectionToken:dataCollectionToken
                                 asUrgent:urgent];
  }

  // deal with stuff in processing more carefully - do not process again
  [self.operationQueue addOperationWithBlock:^{
    for (NSString *path in self.processingReportPaths) {
      FIRCLSInternalReport *report = [FIRCLSInternalReport reportWithPath:path];
      [self.reportUploader prepareAndSubmitReport:report
                              dataCollectionToken:dataCollectionToken
                                         asUrgent:NO
                                   withProcessing:NO];
    }
  }];

  // Because this could happen quite a bit after the inital set of files was
  // captured, some could be completed (deleted). So, just double-check to make sure
  // the file still exists.
  [self.operationQueue addOperationWithBlock:^{
    for (NSString *path in self.preparedReportPaths) {
      if (![[self.fileManager underlyingFileManager] fileExistsAtPath:path]) {
        continue;
      }
      [self.reportUploader uploadPackagedReportAtPath:path
                                  dataCollectionToken:dataCollectionToken
                                             asUrgent:NO];
    }
  }];
}

- (void)processExistingActiveReportPath:(NSString *)path
                    dataCollectionToken:(FIRCLSDataCollectionToken *)dataCollectionToken
                               asUrgent:(BOOL)urgent {
  FIRCLSInternalReport *report = [FIRCLSInternalReport reportWithPath:path];

  // TODO: hasAnyEvents should really be called on the background queue.
  if (![report hasAnyEvents]) {
    [self.operationQueue addOperationWithBlock:^{
      [self.fileManager removeItemAtPath:path];
    }];

    return;
  }

  if (urgent && [dataCollectionToken isValid]) {
    // We can proceed without the delegate.
    [self.reportUploader prepareAndSubmitReport:report
                            dataCollectionToken:dataCollectionToken
                                       asUrgent:urgent
                                 withProcessing:YES];
    return;
  }

  [self.operationQueue addOperationWithBlock:^{
    [self.reportUploader prepareAndSubmitReport:report
                            dataCollectionToken:dataCollectionToken
                                       asUrgent:NO
                                 withProcessing:YES];
  }];
}

- (void)deleteUnsentReports {
  NSArray<NSString *> *reportPaths = @[];
  reportPaths = [reportPaths arrayByAddingObjectsFromArray:self.existingUnemptyActiveReportPaths];
  reportPaths = [reportPaths arrayByAddingObjectsFromArray:self.processingReportPaths];
  reportPaths = [reportPaths arrayByAddingObjectsFromArray:self.preparedReportPaths];

  [self.operationQueue addOperationWithBlock:^{
    for (NSString *path in reportPaths) {
      [self.fileManager removeItemAtPath:path];
    }
  }];
}

@end
