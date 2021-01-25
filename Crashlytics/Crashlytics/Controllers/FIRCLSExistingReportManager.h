//
//  FIRCLSExistingReportManager.h
//  Pods
//
//  Created by Sam Edson on 1/25/21.
//

#import <Foundation/Foundation.h>

#import "Crashlytics/Crashlytics/Controllers/FIRCLSReportUploader.h"
#import "Crashlytics/Crashlytics/DataCollection/FIRCLSDataCollectionToken.h"
#import "Crashlytics/Crashlytics/Models/FIRCLSFileManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface FIRCLSExistingReportManager : NSObject

- (instancetype)initWithFileManager:(FIRCLSFileManager *)fileManager
                     operationQueue:(NSOperationQueue *)operationQueue
                     reportUploader:(FIRCLSReportUploader *)reportUploader;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (int)unsentReportsCountWithPreexisting:(NSArray<NSString *> *)paths;

- (void)deleteUnsentReportsWithPreexisting:(NSArray *)preexistingReportPaths;

- (void)processExistingReportPaths:(NSArray *)reportPaths
               dataCollectionToken:(FIRCLSDataCollectionToken *)dataCollectionToken
                          asUrgent:(BOOL)urgent;

- (void)handleContentsInOtherReportingDirectoriesWithToken:(FIRCLSDataCollectionToken *)token;

@end

NS_ASSUME_NONNULL_END
