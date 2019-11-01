//
//  FIRHeartbeatInfo.m
//  AppHost-FirebaseInstanceID-iOS-Unit-Tests
//
//  Created by Vinay Guthal on 10/17/19.
//

#import "FIRHeartbeatInfo.h"
#import <GoogleUtilities/GULLogger.h>
#import <GoogleUtilities/GULHeartbeatDateStorage.h>

@implementation FIRHeartbeatInfo : NSObject

+ (BOOL)getOrUpdateHeartbeat:(NSString *)prefKey {
  @synchronized(self) {
    NSString *const kHeartbeatStorageFile = @"HEARTBEAT_INFO_STORAGE";
    GULHeartbeatDateStorage *dataStorage = [[GULHeartbeatDateStorage alloc]
        initWithFileURL:[GULHeartbeatDateStorage filePathURLWithName:kHeartbeatStorageFile]];
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

+ (enum FIRHeartbeatInfoCode)getHeartbeatCode:(NSString *)heartbeatTag {
  NSString *globalTag = @"GLOBAL";
  BOOL isSdkHeartbeatNeeded = [FIRHeartbeatInfo getOrUpdateHeartbeat:heartbeatTag];
  BOOL isGlobalHeartbeatNeeded = [FIRHeartbeatInfo getOrUpdateHeartbeat:globalTag];
  if (!isSdkHeartbeatNeeded && !isGlobalHeartbeatNeeded) {
    // Both sdk and global heartbeat not needed.
    return FIRHeartbeatInfoCodeNone;
  } else if (isSdkHeartbeatNeeded && !isGlobalHeartbeatNeeded) {
    // Only SDK heartbeat needed.
    return FIRHeartbeatInfoCodeSdk;
  } else if (!isSdkHeartbeatNeeded && isGlobalHeartbeatNeeded) {
    // Only global heartbeat needed.
    return FIRHeartbeatInfoCodeGlobal;
  } else {
    // Both sdk and global heartbeat are needed.
    return FIRHeartbeatInfoCodeNone;
  }
}
@end
