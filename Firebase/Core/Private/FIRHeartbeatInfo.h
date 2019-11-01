//
//  HeartbeatInfo.h
//  AppHost-FirebaseInstanceID-iOS-Unit-Tests
//
//  Created by Vinay Guthal on 10/17/19.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FIRHeartbeatInfo : NSObject

typedef NS_ENUM(NSInteger, Heartbeat) {
  kFIRHeartbeatInfoNone = 0,
  kFIRHeartbeatInfoSdk = 1,
  kFIRHeartbeatInfoGlobal = 2,
  kFIRHeartbeatInfoCombined = 3,
};


+ (Heartbeat)getHeartbeatCode:(NSString *)heartbeatTag;

@end

NS_ASSUME_NONNULL_END
