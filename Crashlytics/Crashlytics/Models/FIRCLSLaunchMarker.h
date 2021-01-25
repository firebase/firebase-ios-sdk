//
//  FIRCLSLaunchMarker.h
//  Pods
//
//  Created by Sam Edson on 1/25/21.
//

#import <Foundation/Foundation.h>

#import "Crashlytics/Crashlytics/Models/FIRCLSFileManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface FIRCLSLaunchMarker : NSObject

- (instancetype)initWithFileManager:(FIRCLSFileManager *)fileManager;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (BOOL)checkForAndCreateLaunchMarker;
- (BOOL)createLaunchFailureMarker;
- (BOOL)removeLaunchFailureMarker;

@end

NS_ASSUME_NONNULL_END
