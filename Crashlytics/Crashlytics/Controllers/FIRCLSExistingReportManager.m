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
#import "Crashlytics/Crashlytics/Models/FIRCLSFileManager.h"
#import "Crashlytics/Crashlytics/Models/FIRCLSInternalReport.h"
#import "Crashlytics/Crashlytics/Private/FIRCrashlyticsReport_Private.h"
#import "Crashlytics/Crashlytics/Public/FirebaseCrashlytics/FIRCrashlyticsReport.h"

@interface FIRCLSExistingReportManager ()

@property(nonatomic, strong) FIRCLSFileManager *fileManager;
@property(nonatomic, strong) NSOperationQueue *operationQueue;
@property(nonatomic, strong) FIRCLSReportUploader *reportUploader;

// This list of active reports excludes the brand new active report that will be created this run of
// the app.
@property(nonatomic, strong) NSArray *existingUnemptyActiveReportPaths;
@property(nonatomic, strong) NSArray *processingReportPaths;
@property(nonatomic, strong) NSArray *preparedReportPaths;

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

NSInteger compareOlder(FIRCLSInternalReport *reportA,
                       FIRCLSInternalReport *reportB,
                       void *context) {
  return [reportA.dateCreated compare:reportB.dateCreated];
}

- (void)collectExistingReports {
  self.existingUnemptyActiveReportPaths =
      [self getUnemptyExistingActiveReportsAndDeleteEmpty:self.fileManager.activePathContents];
  self.processingReportPaths = self.fileManager.processingPathContents;
  self.preparedReportPaths = self.fileManager.preparedPathContents;
}

- (FIRCrashlyticsReport *)newestUnsentReport {
  if (self.unsentReportsCount <= 0) {
    return nil;
  }

  NSMutableArray<NSString *> *allReportPaths =
      [NSMutableArray arrayWithArray:self.existingUnemptyActiveReportPaths];

  NSMutableArray<FIRCLSInternalReport *> *validReports = [NSMutableArray array];
  for (NSString *path in allReportPaths) {
    FIRCLSInternalReport *_Nullable report = [FIRCLSInternalReport reportWithPath:path];
    if (!report) {
      continue;
    }
    [validReports addObject:report];
  }

  [validReports sortUsingFunction:compareOlder context:nil];

  FIRCLSInternalReport *_Nullable internalReport = [validReports lastObject];
  return [[FIRCrashlyticsReport alloc] initWithInternalReport:internalReport];
}

- (NSUInteger)unsentReportsCount {
  // There are nuances about why we only count active reports.
  // See the header comment for more information.
  return self.existingUnemptyActiveReportPaths.count;
}

- (NSArray *)getUnemptyExistingActiveReportsAndDeleteEmpty:(NSArray *)reportPaths {
  NSMutableArray *unemptyReports = [NSMutableArray array];
  for (NSString *path in reportPaths) {
    FIRCLSInternalReport *report = [FIRCLSInternalReport reportWithPath:path];
    if ([report hasAnyEvents]) {
      [unemptyReports addObject:path];
    } else {
      [self.operationQueue addOperationWithBlock:^{
        [self.fileManager removeItemAtPath:path];
      }];
    }
  }
  return unemptyReports;
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
