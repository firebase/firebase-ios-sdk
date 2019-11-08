//
//  FIRHeartbeatInfo.m
//  AppHost-FirebaseInstanceID-iOS-Unit-Tests
//
//  Created by Vinay Guthal on 10/17/19.
//

#import "FIRHeartbeatInfo.h"
#import <GoogleUtilities/GULHeartbeatDateStorage.h>
#import <GoogleUtilities/GULLogger.h>

@implementation FIRHeartbeatInfo : NSObject

+ (BOOL)updateIfNeededHeartbeatDateForTag:(NSString *)heartbeatTag {
  @synchronized(self) {
    NSString *const kHeartbeatStorageFile = @"HEARTBEAT_INFO_STORAGE";
    GULHeartbeatDateStorage *dataStorage =
        [[GULHeartbeatDateStorage alloc] initWithFileName:kHeartbeatStorageFile];
    NSDate *heartbeatTime = [dataStorage heartbeatDateForTag:heartbeatTag];
    NSDate *currentDate = [NSDate date];
    if (heartbeatTime != nil) {
      NSTimeInterval secondsBetween = [currentDate timeIntervalSinceDate:heartbeatTime];
      if (secondsBetween < 84000) {
        return false;
      }
    }
    return [dataStorage setHearbeatDate:currentDate forTag:heartbeatTag];
  }
}

+ (FIRHeartbeatInfoCode)heartbeatCodeForTag:(NSString *)heartbeatTag {
  NSString *globalTag = @"GLOBAL";
  BOOL isSdkHeartbeatNeeded = [FIRHeartbeatInfo updateIfNeededHeartbeatDateForTag:heartbeatTag];
  BOOL isGlobalHeartbeatNeeded = [FIRHeartbeatInfo updateIfNeededHeartbeatDateForTag:globalTag];
  if (!isSdkHeartbeatNeeded && !isGlobalHeartbeatNeeded) {
    // Both sdk and global heartbeat not needed.
    return FIRHeartbeatInfoCodeNone;
  } else if (isSdkHeartbeatNeeded && !isGlobalHeartbeatNeeded) {
    // Only SDK heartbeat needed.
    return FIRHeartbeatInfoCodeSDK;
  } else if (!isSdkHeartbeatNeeded && isGlobalHeartbeatNeeded) {
    // Only global heartbeat needed.
    return FIRHeartbeatInfoCodeGLOBAL;
  } else {
    // Both sdk and global heartbeat are needed.
    return FIRHeartbeatInfoCodeCOMBINED;
  }
}
@end
