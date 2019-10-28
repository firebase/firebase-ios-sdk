//
//  FIRHeartbeatInfo.m
//  AppHost-FirebaseInstanceID-iOS-Unit-Tests
//
//  Created by Vinay Guthal on 10/17/19.
//

#import "FIRHeartbeatInfo.h"
#import <GoogleUtilities/GULLogger.h>
#import <GoogleUtilities/GULStorageHeartbeat.h>

@implementation FIRHeartbeatInfo : NSObject

/** The logger service string to use when printing to the console. */
static GULLoggerService kFIRHeartbeatInfo = @"FIRHeartbeatInfo";

/** Returns the URL path of the file with name fileName under the Application Support folder for
 * local logging. Creates the Application Support folder if the folder doesn't exist.
 *
 * @return the URL path of the file with the name fileName in Application Support.
 */
+ (NSURL *)filePathURLWithName:(NSString *)fileName {
  @synchronized(self) {
    NSArray<NSString *> *paths =
        NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSArray<NSString *> *components = @[ paths.lastObject, @"Google/FIRApp" ];
    NSString *directoryString = [NSString pathWithComponents:components];
    NSURL *directoryURL = [NSURL fileURLWithPath:directoryString];

    NSError *error;
    if (![directoryURL checkResourceIsReachableAndReturnError:&error]) {
      // If fail creating the Application Support directory, return nil.
      if (![[NSFileManager defaultManager] createDirectoryAtURL:directoryURL
                                    withIntermediateDirectories:YES
                                                     attributes:nil
                                                          error:&error]) {
        GULLogWarning(kFIRHeartbeatInfo, YES, @"I-COR100001",
                      @"Unable to create internal state storage: %@", error);
        return nil;
      }
    }
    return [directoryURL URLByAppendingPathComponent:fileName];
  }
}

+ (BOOL)getOrUpdateHeartbeat:(NSString *)prefKey {
  @synchronized(self) {
    NSString *const kHeartbeatStorageFile = @"HEARTBEAT_INFO_STORAGE";
    GULStorageHeartbeat *dataStorage = [[GULStorageHeartbeat alloc]
        initWithFileURL:[[self class] filePathURLWithName:kHeartbeatStorageFile]];
    NSDate *heartbeatTime = [dataStorage heartbeatDateForTag:prefKey];
    NSDate *currentDate = [NSDate date];
    if (heartbeatTime != nil) {
      NSTimeInterval secondsBetween = [currentDate timeIntervalSinceDate:heartbeatTime];
      if (secondsBetween < 84000) {
        return false;
      }
    }
    return [dataStorage setHearbeatDate:currentDate forTag:prefKey];
  }
}

+ (enum Heartbeat)getHeartbeatCode:(NSString *)heartbeatTag {
  NSString *globalTag = @"GLOBAL";
  BOOL isSdkHeartbeatNeeded = [FIRHeartbeatInfo getOrUpdateHeartbeat:heartbeatTag];
  BOOL isGlobalHeartbeatNeeded = [FIRHeartbeatInfo getOrUpdateHeartbeat:globalTag];
  if (!isSdkHeartbeatNeeded && !isGlobalHeartbeatNeeded) {
    // Both sdk and global heartbeat not needed.
    return kFIRHeartbeatInfoNone;
  } else if (isSdkHeartbeatNeeded && !isGlobalHeartbeatNeeded) {
    // Only SDK heartbeat needed.
    return kFIRHeartbeatInfoSdk;
  } else if (!isSdkHeartbeatNeeded && isGlobalHeartbeatNeeded) {
    // Only global heartbeat needed.
    return kFIRHeartbeatInfoGlobal;
  } else {
    // Both sdk and global heartbeat are needed.
    return kFIRHeartbeatInfoCombined;
  }
}
@end
