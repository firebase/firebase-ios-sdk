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

#import "Crashlytics/UnitTests/Mocks/FIRCLSMockReportUploader.h"

#import "Crashlytics/Crashlytics/Models/FIRCLSFileManager.h"
#import "Crashlytics/Crashlytics/Models/FIRCLSInternalReport.h"

@interface FIRCLSMockReportUploader () {
  NSMutableArray *_prepareAndSubmitReportArray;
  NSMutableArray *_uploadReportArray;
}

@end

@implementation FIRCLSMockReportUploader

- (instancetype)initWithQueue:(NSOperationQueue *)queue
                     delegate:(id<FIRCLSReportUploaderDelegate>)delegate
                   dataSource:(id<FIRCLSReportUploaderDataSource>)dataSource
                       client:(FIRCLSNetworkClient *)client
                  fileManager:(FIRCLSFileManager *)fileManager
                    analytics:(id<FIRAnalyticsInterop>)analytics {
  self = [super initWithQueue:queue
                     delegate:delegate
                   dataSource:dataSource
                       client:client
                  fileManager:fileManager
                    analytics:analytics];
  if (!self) {
    return nil;
  }

  _prepareAndSubmitReportArray = [[NSMutableArray alloc] init];
  _uploadReportArray = [[NSMutableArray alloc] init];

  return self;
}

- (BOOL)prepareAndSubmitReport:(FIRCLSInternalReport *)report
           dataCollectionToken:(FIRCLSDataCollectionToken *)dataCollectionToken
                      asUrgent:(BOOL)urgent
                withProcessing:(BOOL)shouldProcess {
  [_prepareAndSubmitReportArray
      addObject:@{@"report" : report, @"urgent" : @(urgent), @"process" : @(shouldProcess)}];

  // report should be from active/processing here. We just need to "move" it.
  [self.fileManager removeItemAtPath:report.path];

  return YES;
}

- (BOOL)uploadPackagedReportAtPath:(NSString *)path
               dataCollectionToken:(FIRCLSDataCollectionToken *)dataCollectionToken
                          asUrgent:(BOOL)urgent {
  [_uploadReportArray addObject:@{@"path" : path, @"urgent" : @(urgent)}];

  // After upload, the file should be removed.
  [self.fileManager removeItemAtPath:path];

  return YES;
}

@end
