//
//  FIRHeartbeatInfo.m
//  AppHost-FirebaseInstanceID-iOS-Unit-Tests
//
//  Created by Vinay Guthal on 10/17/19.
//

#import <GoogleUtilities/GULLogger.h>
#import <GoogleUtilities/GULStorageHeartbeat.h>
#import "FIRHeartbeatInfo.h"

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


+ (BOOL) getOrUpdateHeartbeat:(NSString *) prefKey {
  NSString *const kHeartbeatStorageFile = @"HEARTBEAT_INFO_STORAGE";
  
  GULStorageHeartbeat *dataStorage = [[GULStorageHeartbeat alloc]
                                                    initWithFileURL:[[self class] filePathURLWithName:kHeartbeatStorageFile]];
  NSInteger timeInSeconds = [[NSDate date] timeIntervalSince1970];
  NSMutableDictionary* heartbeatInfo = [dataStorage getDictionary];
  if(heartbeatInfo == nil) return false;
  if ([heartbeatInfo objectForKey:prefKey] == nil)
  {
    [heartbeatInfo setValue: [NSString stringWithFormat:@"%ld", timeInSeconds] forKey:prefKey];
  }
  else
  {
    NSInteger lastHeartbeatTime = [[heartbeatInfo objectForKey:prefKey] intValue];
    if((timeInSeconds-lastHeartbeatTime) > 24*60*60) {
      [heartbeatInfo setValue: [NSString stringWithFormat:@"%ld", timeInSeconds] forKey:prefKey];
    }
    else {
      return false;
    }
  }
  NSError *error;
  if(![dataStorage writeDictionary:heartbeatInfo error:&error]) {
    GULLogError(kFIRHeartbeatInfo, NO, @"I-COR100004", @"Unable to persist internal state: %@",
                error);
  }


  return false;
}

+ (NSInteger) getHeartbeatCode:(NSString *) heartbeatTag {
  NSString *globalTag = @"GLOBAL";
  BOOL isSdkHeartbeatNeeded = [FIRHeartbeatInfo getOrUpdateHeartbeat:heartbeatTag];
  BOOL isGlobalHeartbeatNeeded = [FIRHeartbeatInfo getOrUpdateHeartbeat:globalTag];
  if(!isSdkHeartbeatNeeded && !isGlobalHeartbeatNeeded) {
    // Both sdk and global heartbeat not needed.
    return 0;
  }
  else if(isSdkHeartbeatNeeded && !isGlobalHeartbeatNeeded) {
    // Only sdk heartbeat needed.
    return 1;
  }
  else if(!isSdkHeartbeatNeeded && isGlobalHeartbeatNeeded) {
    // Only global heartbeat needed.
    return 2;
  }
  else {
    // Both sdk and global heartbeat are needed.
    return 3;
  }

}
@end
