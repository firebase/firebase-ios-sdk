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

#import <Foundation/Foundation.h>

@class FIRCLSDataCollectionToken;
@class FIRCLSInternalReport;
@class FIRCLSManagerData;
@class FIRCLSFileManager;

@interface FIRCLSReportUploader : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)initWithManagerData:(FIRCLSManagerData *)managerData NS_DESIGNATED_INITIALIZER;

@property(nonatomic, readonly) NSOperationQueue *operationQueue;
@property(nonatomic, readonly) FIRCLSFileManager *fileManager;

- (void)prepareAndSubmitReport:(FIRCLSInternalReport *)report
           dataCollectionToken:(FIRCLSDataCollectionToken *)dataCollectionToken
                      asUrgent:(BOOL)urgent
                withProcessing:(BOOL)shouldProcess;

- (void)uploadPackagedReportAtPath:(NSString *)path
               dataCollectionToken:(FIRCLSDataCollectionToken *)dataCollectionToken
                          asUrgent:(BOOL)urgent;

@end
