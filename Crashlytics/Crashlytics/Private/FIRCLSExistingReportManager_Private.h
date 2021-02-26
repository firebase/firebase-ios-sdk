//
//  FIRCLSExistingReportManager_Private.h
//  Pods
//
//  Created by Sam Edson on 2/26/21.
//

#ifndef FIRCLSExistingReportManager_Private_h
#define FIRCLSExistingReportManager_Private_h

#import "Crashlytics/Crashlytics/Controllers/FIRCLSExistingReportManager.h"

/**
 * Visible for testing
 */
@interface FIRCLSExistingReportManager (Private)

@property(nonatomic, strong) NSOperationQueue *operationQueue;

@property(nonatomic, strong) NSArray *existingUnemptyActiveReportPaths;
@property(nonatomic, strong) NSArray *processingReportPaths;
@property(nonatomic, strong) NSArray *preparedReportPaths;

@end

#endif /* FIRCLSExistingReportManager_Private_h */
