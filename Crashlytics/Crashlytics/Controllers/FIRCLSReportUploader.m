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

#import <FirebaseAnalyticsInterop/FIRAnalyticsInterop.h>

#import "FIRCLSApplication.h"
#import "FIRCLSDataCollectionArbiter.h"
#import "FIRCLSDataCollectionToken.h"
#import "FIRCLSDefines.h"
#import "FIRCLSFCRAnalytics.h"
#import "FIRCLSFileManager.h"
#import "FIRCLSInstallIdentifierModel.h"
#import "FIRCLSInternalReport.h"
#import "FIRCLSNetworkClient.h"
#import "FIRCLSPackageReportOperation.h"
#import "FIRCLSProcessReportOperation.h"
#import "FIRCLSReportUploader_Private.h"
#import "FIRCLSSettings.h"
#import "FIRCLSSymbolResolver.h"

#include "FIRCLSUtility.h"

#import "FIRCLSConstants.h"
#import "FIRCLSMultipartMimeStreamEncoder.h"
#import "FIRCLSURLBuilder.h"

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

#pragma mark - Properties

- (NSURL *)reportURL {
  FIRCLSURLBuilder *url = [FIRCLSURLBuilder URLWithBase:FIRCLSReportsEndpoint];

  [url appendComponent:@"/sdk-api/v1/platforms/"];
  [url appendComponent:FIRCLSApplicationGetPlatform()];
  [url appendComponent:@"/apps/"];
  [url appendComponent:self.dataSource.settings.fetchedBundleID];
  [url appendComponent:@"/reports"];

  return [url URL];
}

- (NSString *)localeIdentifier {
  return [[NSLocale currentLocale] localeIdentifier];
}

#pragma mark - URL Requests
- (NSMutableURLRequest *)mutableRequestWithURL:(NSURL *)url timeout:(NSTimeInterval)timeout {
  NSMutableURLRequest *request =
      [NSMutableURLRequest requestWithURL:url
                              cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                          timeoutInterval:timeout];

  NSString *localeId = [self localeIdentifier];

  [request setValue:@CLS_SDK_GENERATOR_NAME forHTTPHeaderField:FIRCLSNetworkUserAgent];
  [request setValue:FIRCLSNetworkApplicationJson forHTTPHeaderField:FIRCLSNetworkAccept];
  [request setValue:FIRCLSNetworkUTF8 forHTTPHeaderField:FIRCLSNetworkAcceptCharset];
  [request setValue:localeId forHTTPHeaderField:FIRCLSNetworkAcceptLanguage];
  [request setValue:localeId forHTTPHeaderField:FIRCLSNetworkContentLanguage];
  [request setValue:FIRCLSDeveloperToken forHTTPHeaderField:FIRCLSNetworkCrashlyticsDeveloperToken];
  [request setValue:FIRCLSApplicationGetSDKBundleID()
      forHTTPHeaderField:FIRCLSNetworkCrashlyticsAPIClientId];
  [request setValue:@CLS_SDK_DISPLAY_VERSION
      forHTTPHeaderField:FIRCLSNetworkCrashlyticsAPIClientDisplayVersion];
  [request setValue:[[self dataSource] googleAppID]
      forHTTPHeaderField:FIRCLSNetworkCrashlyticsGoogleAppId];

  return request;
}

- (BOOL)fillInRequest:(NSMutableURLRequest *)request forMultipartMimeDataAtPath:(NSString *)path {
  NSString *boundary = [[path lastPathComponent] stringByDeletingPathExtension];

  [request setValue:[FIRCLSMultipartMimeStreamEncoder
                        contentTypeHTTPHeaderValueWithBoundary:boundary]
      forHTTPHeaderField:@"Content-Type"];

  NSNumber *fileSize = [[self fileManager] fileSizeAtPath:path];
  if (fileSize == nil) {
    FIRCLSErrorLog(@"Could not determine size of multipart mime file");
    return NO;
  }

  [request setValue:[fileSize stringValue] forHTTPHeaderField:@"Content-Length"];

  return YES;
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

  NSString *reportOrgID = self.dataSource.settings.orgID;
  if (!reportOrgID) {
    FIRCLSDebugLog(@"Skipping report with id '%@' this run of the app because Organization ID was "
                   @"nil. Report will upload once settings are download successfully",
                   report.identifier);
    return YES;
  }

  FIRCLSApplicationActivity(
      FIRCLSApplicationActivityDefault, @"Crashlytics Crash Report Processing", ^{
        if (shouldProcess) {
          if (![self.fileManager moveItemAtPath:[report path]
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

        FIRCLSPackageReportOperation *packageOperation =
            [[FIRCLSPackageReportOperation alloc] initWithReport:report
                                                     fileManager:self.fileManager
                                                        settings:self.dataSource.settings];

        [packageOperation start];

        NSString *packagedPath = [packageOperation finalPath];
        if (!packagedPath) {
          FIRCLSErrorLog(@"Unable to package report");
          return;
        }

        // Save the crashed on date for potential scion event sending.
        NSTimeInterval crashedOnDate = report.crashedOnDate.timeIntervalSince1970;
        // We only want to forward crash events to scion, storing this for later use.
        BOOL isCrash = report.isCrash;

        if (![[self fileManager] removeItemAtPath:[report path]]) {
          FIRCLSErrorLog(@"Unable to remove a processing item");
        }

        NSLog(@"[Firebase/Crashlytics] Packaged report with id '%@' for submission",
              report.identifier);

        success = [self uploadPackagedReportAtPath:packagedPath
                               dataCollectionToken:dataCollectionToken
                                          asUrgent:urgent];

        // If the upload was successful and the report contained a crash forward it to scion.
        if (success && isCrash) {
          [FIRCLSFCRAnalytics logCrashWithTimeStamp:crashedOnDate toAnalytics:self->_analytics];
        }
      });

  return success;
}

- (BOOL)submitPackageMultipartMimeAtPath:(NSString *)multipartmimePath
                     dataCollectionToken:(FIRCLSDataCollectionToken *)dataCollectionToken
                           synchronously:(BOOL)synchronous {
  FIRCLSDeveloperLog(@"Crashlytics:Crash:Reports", "Submitting %@ %@",
                     synchronous ? @"sync" : @"async", multipartmimePath);

  if ([[[self fileManager] fileSizeAtPath:multipartmimePath] unsignedIntegerValue] == 0) {
    FIRCLSDeveloperLog("Crashlytics:Crash:Reports", @"Already-submitted report being ignored");
    return NO;
  }

  NSTimeInterval timeout = 10.0;

  // If we are submitting synchronously, be more aggressive with the timeout. However,
  // we only need this if the client does not support background requests.
  if (synchronous && ![[self networkClient] supportsBackgroundRequests]) {
    timeout = 2.0;
  }

  NSMutableURLRequest *request = [self mutableRequestWithURL:[self reportURL] timeout:timeout];

  [request setHTTPMethod:@"POST"];

  if (![self fillInRequest:request forMultipartMimeDataAtPath:multipartmimePath]) {
    return NO;
  }

  [[self networkClient] startUploadRequest:request
                                  filePath:multipartmimePath
                       dataCollectionToken:dataCollectionToken
                               immediately:synchronous];

  return YES;
}

- (BOOL)uploadPackagedReportAtPath:(NSString *)path
               dataCollectionToken:(FIRCLSDataCollectionToken *)dataCollectionToken
                          asUrgent:(BOOL)urgent {
  FIRCLSDeveloperLog("Crashlytics:Crash:Reports", @"Submitting report%@",
                     urgent ? @" as urgent" : @"");
  return [self submitPackageMultipartMimeAtPath:path
                            dataCollectionToken:dataCollectionToken
                                  synchronously:urgent];
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
