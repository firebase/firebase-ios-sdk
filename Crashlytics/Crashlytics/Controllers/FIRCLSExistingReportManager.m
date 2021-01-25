//
//  FIRCLSExistingReportManager.m
//  Pods
//
//  Created by Sam Edson on 1/25/21.
//

#import "FIRCLSExistingReportManager.h"

#import "Crashlytics/Crashlytics/Helpers/FIRCLSLogger.h"
#import "Crashlytics/Crashlytics/Models/FIRCLSInternalReport.h"

@interface FIRCLSExistingReportManager ()

@property(nonatomic, strong) FIRCLSFileManager *fileManager;
@property(nonatomic, strong) NSOperationQueue *operationQueue;
@property(nonatomic, strong) FIRCLSReportUploader *reportUploader;

@end

@implementation FIRCLSExistingReportManager

- (instancetype)initWithFileManager:(FIRCLSFileManager *)fileManager
                     operationQueue:(NSOperationQueue *)operationQueue
                     reportUploader:(FIRCLSReportUploader *)reportUploader {
  self = [super init];
  if (!self) {
    return nil;
  }

  _fileManager = fileManager;
  _operationQueue = operationQueue;
  _reportUploader = reportUploader;

  return self;
}

/**
 * Returns the number of unsent reports on the device, including the ones passed in.
 */
- (int)unsentReportsCountWithPreexisting:(NSArray<NSString *> *)paths {
  int count = [self countSubmittableAndDeleteUnsubmittableReportPaths:paths];

  count += self.fileManager.processingPathContents.count;
  count += self.fileManager.preparedPathContents.count;
  return count;
}

- (int)countSubmittableAndDeleteUnsubmittableReportPaths:(NSArray *)reportPaths {
  int count = 0;
  for (NSString *path in reportPaths) {
    FIRCLSInternalReport *report = [FIRCLSInternalReport reportWithPath:path];
    if ([report needsToBeSubmitted]) {
      count++;
    } else {
      [self.operationQueue addOperationWithBlock:^{
        [self->_fileManager removeItemAtPath:path];
      }];
    }
  }
  return count;
}

- (void)processExistingReportPaths:(NSArray *)reportPaths
               dataCollectionToken:(FIRCLSDataCollectionToken *)dataCollectionToken
                          asUrgent:(BOOL)urgent {
  for (NSString *path in reportPaths) {
    [self processExistingActiveReportPath:path
                      dataCollectionToken:dataCollectionToken
                                 asUrgent:urgent];
  }
}

- (void)processExistingActiveReportPath:(NSString *)path
                    dataCollectionToken:(FIRCLSDataCollectionToken *)dataCollectionToken
                               asUrgent:(BOOL)urgent {
  FIRCLSInternalReport *report = [FIRCLSInternalReport reportWithPath:path];

  // TODO: needsToBeSubmitted should really be called on the background queue.
  if (![report needsToBeSubmitted]) {
    [self.operationQueue addOperationWithBlock:^{
      [self->_fileManager removeItemAtPath:path];
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

  [self submitReport:report dataCollectionToken:dataCollectionToken];
}

- (void)submitReport:(FIRCLSInternalReport *)report
    dataCollectionToken:(FIRCLSDataCollectionToken *)dataCollectionToken {
  [self.operationQueue addOperationWithBlock:^{
    [self.reportUploader prepareAndSubmitReport:report
                            dataCollectionToken:dataCollectionToken
                                       asUrgent:NO
                                 withProcessing:YES];
  }];
}

// This is the side-effect of calling deleteUnsentReports, or collect_reports setting
// being false
- (void)deleteUnsentReportsWithPreexisting:(NSArray *)preexistingReportPaths {
  [self removeExistingReportPaths:preexistingReportPaths];
  [self removeExistingReportPaths:self.fileManager.processingPathContents];
  [self removeExistingReportPaths:self.fileManager.preparedPathContents];
}

- (void)removeExistingReportPaths:(NSArray *)reportPaths {
  [self.operationQueue addOperationWithBlock:^{
    for (NSString *path in reportPaths) {
      [self.fileManager removeItemAtPath:path];
    }
  }];
}

- (void)handleContentsInOtherReportingDirectoriesWithToken:(FIRCLSDataCollectionToken *)token {
  [self handleExistingFilesInProcessingWithToken:token];
  [self handleExistingFilesInPreparedWithToken:token];
}

- (void)handleExistingFilesInProcessingWithToken:(FIRCLSDataCollectionToken *)token {
  NSArray *processingPaths = _fileManager.processingPathContents;

  // deal with stuff in processing more carefully - do not process again
  [self.operationQueue addOperationWithBlock:^{
    for (NSString *path in processingPaths) {
      FIRCLSInternalReport *report = [FIRCLSInternalReport reportWithPath:path];
      [self.reportUploader prepareAndSubmitReport:report
                              dataCollectionToken:token
                                         asUrgent:NO
                                   withProcessing:NO];
    }
  }];
}

- (void)handleExistingFilesInPreparedWithToken:(FIRCLSDataCollectionToken *)token {
  NSArray *preparedPaths = self.fileManager.preparedPathContents;
  [self.operationQueue addOperationWithBlock:^{
    [self uploadPreexistingFiles:preparedPaths withToken:token];
  }];
}

- (void)uploadPreexistingFiles:(NSArray *)files withToken:(FIRCLSDataCollectionToken *)token {
  // Because this could happen quite a bit after the inital set of files was
  // captured, some could be completed (deleted). So, just double-check to make sure
  // the file still exists.

  for (NSString *path in files) {
    if (![[_fileManager underlyingFileManager] fileExistsAtPath:path]) {
      continue;
    }

    [self.reportUploader uploadPackagedReportAtPath:path dataCollectionToken:token asUrgent:NO];
  }
}

@end
