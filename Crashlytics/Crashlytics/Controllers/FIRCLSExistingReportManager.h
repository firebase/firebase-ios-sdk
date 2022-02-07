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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class FIRCLSManagerData;
@class FIRCLSReportUploader;
@class FIRCLSDataCollectionToken;
@class FIRCrashlyticsReport;

FOUNDATION_EXPORT NSUInteger const FIRCLSMaxUnsentReports;

@interface FIRCLSExistingReportManager : NSObject

/**
 * Returns the number of unsent reports on the device, ignoring empty reports in
 * the active folder, and ignoring any reports in "processing" or "prepared".
 *
 * In the past, this would count reports in the processed or prepared
 * folders. This has been changed because reports in those paths have already
 * been cleared for upload, so there isn't any point in asking for permission
 * or possibly spamming end-users if a report gets stuck.
 *
 * The tricky part is, customers will NOT be alerted in `checkForUnsentReports`
 * for reports in these paths, but when they choose `sendUnsentReports` / enable data
 * collection, reports in those directories will be re-managed. This should be ok and
 * just an edge case because reports should only be in processing or prepared for a split second as
 * they do on-device symbolication and get converted into a GDTEvent. After a report is handed off
 * to GoogleDataTransport, it is uploaded regardless of Crashlytics data collection.
 */
@property(nonatomic, readonly) NSUInteger unsentReportsCount;

/**
 * This value needs to stay in sync with `numUnsentReports`, so if there is > 0 `numUnsentReports`,
 * `newestUnsentReport` needs to return a value. Otherwise it needs to return nil.
 *
 * `FIRCLSContext` needs to be initialized before the `CrashlyticsReport` is instantiated.
 */
@property(nonatomic, readonly) FIRCrashlyticsReport *_Nullable newestUnsentReport;

- (instancetype)initWithManagerData:(FIRCLSManagerData *)managerData
                     reportUploader:(FIRCLSReportUploader *)reportUploader;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

/**
 * This is important to call once, early in startup, before the
 * new report for this run of the app has been created. Any
 * reports in `ExistingReportManager` will be uploaded or deleted
 * and we don't want to do that for the current run of the app.
 *
 * If there are over MAX_UNSENT_REPORTS valid reports, this will delete them.
 *
 * This methods is slow and should be called only once.
 */
- (void)collectExistingReports;

/**
 * This is the side-effect of calling `deleteUnsentReports`, or collect_reports setting
 * being false.
 */
- (void)deleteUnsentReports;

- (void)sendUnsentReportsWithToken:(FIRCLSDataCollectionToken *)dataCollectionToken
                          asUrgent:(BOOL)urgent;

@end

NS_ASSUME_NONNULL_END
