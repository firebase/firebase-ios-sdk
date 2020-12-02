// Copyright 2019 Google
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

#import "Interop/Analytics/Public/FIRAnalyticsInterop.h"

#import "Crashlytics/Crashlytics/Components/FIRCLSApplication.h"
#import "Crashlytics/Crashlytics/Controllers/FIRCLSNetworkClient.h"
#import "Crashlytics/Crashlytics/Controllers/FIRCLSReportUploader_Private.h"
#import "Crashlytics/Crashlytics/DataCollection/FIRCLSDataCollectionArbiter.h"
#import "Crashlytics/Crashlytics/DataCollection/FIRCLSDataCollectionToken.h"
#import "Crashlytics/Crashlytics/Helpers/FIRCLSDefines.h"
#import "Crashlytics/Crashlytics/Helpers/FIRCLSFCRAnalytics.h"
#import "Crashlytics/Crashlytics/Models/FIRCLSFileManager.h"
#import "Crashlytics/Crashlytics/Models/FIRCLSInstallIdentifierModel.h"
#import "Crashlytics/Crashlytics/Models/FIRCLSInternalReport.h"
#import "Crashlytics/Crashlytics/Models/FIRCLSSettings.h"
#import "Crashlytics/Crashlytics/Models/FIRCLSSymbolResolver.h"
#import "Crashlytics/Crashlytics/Models/Record/FIRCLSReportAdapter.h"
#import "Crashlytics/Crashlytics/Operations/Reports/FIRCLSPackageReportOperation.h"
#import "Crashlytics/Crashlytics/Operations/Reports/FIRCLSProcessReportOperation.h"

#include "Crashlytics/Crashlytics/Helpers/FIRCLSUtility.h"

#import "Crashlytics/Shared/FIRCLSConstants.h"
#import "Crashlytics/Shared/FIRCLSNetworking/FIRCLSMultipartMimeStreamEncoder.h"
#import "Crashlytics/Shared/FIRCLSNetworking/FIRCLSURLBuilder.h"

#import "GoogleDataTransport/GDTCORLibrary/Internal/GoogleDataTransportInternal.h"

@interface FIRCLSReportUploader () {
  id<FIRAnalyticsInterop> _analytics;
}
@end

@implementation FIRCLSReportUploader

- (instancetype)initWithQueue:(NSOperationQueue *)queue
                     delegate:(id<FIRCLSReportUploaderDelegate>)delegate
                   dataSource:(id<FIRCLSReportUploaderDataSource>)dataSource
                       client:(FIRCLSNetworkClient *)client
                  fileManager:(FIRCLSFileManager *)fileManager
                    analytics:(id<FIRAnalyticsInterop>)analytics {
  self = [super init];
  if (!self) {
    return nil;
  }

  _operationQueue = queue;
  _delegate = delegate;
  _dataSource = dataSource;
  _networkClient = client;
  _fileManager = fileManager;
  _analytics = analytics;

  return self;
}

#pragma mark - Packaging and Submission
- (BOOL)prepareAndSubmitReport:(FIRCLSInternalReport *)report
           dataCollectionToken:(FIRCLSDataCollectionToken *)dataCollectionToken
                      asUrgent:(BOOL)urgent
                withProcessing:(BOOL)shouldProcess {
  __block BOOL success = NO;

  if (![dataCollectionToken isValid]) {
    FIRCLSErrorLog(@"Data collection disabled and report will not be submitted");
    return NO;
  }

  FIRCLSApplicationActivity(
      FIRCLSApplicationActivityDefault, @"Crashlytics Crash Report Processing", ^{
        if (shouldProcess) {
          if (![self.fileManager moveItemAtPath:report.path
                                    toDirectory:self.fileManager.processingPath]) {
            FIRCLSErrorLog(@"Unable to move report for processing");
            return;
          }

          // adjust the report's path, and process it
          [report setPath:[self.fileManager.processingPath
                              stringByAppendingPathComponent:report.directoryName]];

          FIRCLSSymbolResolver *resolver = [[FIRCLSSymbolResolver alloc] init];

          FIRCLSProcessReportOperation *processOperation =
              [[FIRCLSProcessReportOperation alloc] initWithReport:report resolver:resolver];

          [processOperation start];
        }

        NSString *packagedPath;

        // With the new report endpoint, the report is deleted once it is written to GDT
        // Check if the report has a crash file before the report is moved or deleted
        BOOL isCrash = report.isCrash;

        // For the new endpoint, just move the .clsrecords from "processing" -> "prepared"
        if (![self.fileManager moveItemAtPath:report.path
                                  toDirectory:self.fileManager.preparedPath]) {
          FIRCLSErrorLog(@"Unable to move report to prepared");
          return;
        }

        packagedPath = [self.fileManager.preparedPath
            stringByAppendingPathComponent:report.path.lastPathComponent];


        NSLog(@"[Firebase/Crashlytics] Packaged report with id '%@' for submission",
              report.identifier);

        success = [self uploadPackagedReportAtPath:packagedPath
                               dataCollectionToken:dataCollectionToken
                                          asUrgent:urgent];

        // If the upload was successful and the report contained a crash forward it to Google
        // Analytics.
        if (success && isCrash) {
          [FIRCLSFCRAnalytics logCrashWithTimeStamp:report.crashedOnDate.timeIntervalSince1970
                                        toAnalytics:self->_analytics];
        }
      });

  return success;
}

- (BOOL)uploadPackagedReportAtPath:(NSString *)path
               dataCollectionToken:(FIRCLSDataCollectionToken *)dataCollectionToken
                          asUrgent:(BOOL)urgent {
  FIRCLSDeveloperLog("Crashlytics:Crash:Reports", @"Submitting report%@",
                     urgent ? @" as urgent" : @"");

  if (![dataCollectionToken isValid]) {
    FIRCLSErrorLog(@"A report upload was requested with an invalid data collection token.");
    return NO;
  }

  FIRCLSReportAdapter *adapter =
      [[FIRCLSReportAdapter alloc] initWithPath:path googleAppId:self.dataSource.googleAppID];

  GDTCOREvent *event = [self.dataSource.googleTransport eventForTransport];
  event.dataObject = adapter;
  event.qosTier = GDTCOREventQoSFast;  // Bypass batching, send immediately

  dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);

  __block BOOL success = YES;

  [self.dataSource.googleTransport
      sendDataEvent:event
         onComplete:^(BOOL wasWritten, NSError *error) {
           if (!wasWritten) {
             FIRCLSDeveloperLog("Crashlytics:Crash:Reports",
                                @"Failed to send crash report due to gdt write failure.");
             success = NO;
             return;
           }

           if (error) {
             FIRCLSDeveloperLog("Crashlytics:Crash:Reports",
                                @"Failed to send crash report due to gdt error: %@",
                                error.localizedDescription);
             success = NO;
             return;
           }

           FIRCLSDeveloperLog("Crashlytics:Crash:Reports",
                              @"Completed report submission with id: %@", path.lastPathComponent);

           if (urgent) {
             dispatch_semaphore_signal(semaphore);
           }

           [self cleanUpSubmittedReportAtPath:path];
         }];

  if (urgent) {
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
  }

  return success;

}

- (BOOL)cleanUpSubmittedReportAtPath:(NSString *)path {
  if (![[self fileManager] removeItemAtPath:path]) {
    FIRCLSErrorLog(@"Unable to remove packaged submission");
    return NO;
  }

  return YES;
}

- (void)reportUploadAtPath:(NSString *)path
       dataCollectionToken:(FIRCLSDataCollectionToken *)dataCollectionToken
        completedWithError:(NSError *)error {
  FIRCLSDeveloperLog("Crashlytics:Crash:Reports", @"completed submission of %@", path);

  if (!error) {
    [self cleanUpSubmittedReportAtPath:path];
  }

  [[self delegate] didCompletePackageSubmission:path
                            dataCollectionToken:dataCollectionToken
                                          error:error];
}

@end
