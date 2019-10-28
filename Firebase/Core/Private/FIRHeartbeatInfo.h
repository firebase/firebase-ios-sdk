//
//  HeartbeatInfo.h
//  AppHost-FirebaseInstanceID-iOS-Unit-Tests
//
//  Created by Vinay Guthal on 10/17/19.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FIRHeartbeatInfo : NSObject

typedef enum Heartbeat {
  NONE = 0,
  SDK = 1,
  GLOBAL = 2,
  COMBINED = 3,
} Heartbeat;

+ (NSURL *)filePathURLWithName:(NSString *)fileName;

+ (Heartbeat)getHeartbeatCode:(NSString *)heartbeatTag;

@end

NS_ASSUME_NONNULL_END
