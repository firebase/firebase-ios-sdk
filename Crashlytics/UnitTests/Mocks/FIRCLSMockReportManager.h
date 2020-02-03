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

#import "FIRCLSReportManager.h"
#import "FIRCLSReportManager_Private.h"

NS_ASSUME_NONNULL_BEGIN

@class FIRCLSApplicationIdentifierModel;
@class FIRCLSMockReportUploader;

@interface FIRCLSMockReportManager : FIRCLSReportManager

- (instancetype)initWithFileManager:(FIRCLSFileManager *)fileManager
                         instanceID:(FIRInstanceID *)instanceID
                          analytics:(nullable id<FIRAnalyticsInterop>)analytics
                        googleAppID:(NSString *)googleAppID
                        dataArbiter:(FIRCLSDataCollectionArbiter *)dataArbiter
                    googleTransport:(GDTCORTransport *)googleTransport NS_DESIGNATED_INITIALIZER;

@property(nonatomic, copy) NSString *bundleIdentifier;

@property(nonatomic, readonly) FIRCLSMockReportUploader *uploader;

@end

NS_ASSUME_NONNULL_END
