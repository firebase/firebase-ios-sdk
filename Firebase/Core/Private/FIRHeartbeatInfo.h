//
//  HeartbeatInfo.h
//  AppHost-FirebaseInstanceID-iOS-Unit-Tests
//
//  Created by Vinay Guthal on 10/17/19.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FIRHeartbeatInfo : NSObject

typedef NS_ENUM(NSInteger, FIRHeartbeatInfoCode) {
  FIRHeartbeatInfoCodeNone = 0,
  FIRHeartbeatInfoCodeSdk = 1,
  FIRHeartbeatInfoCodeGlobal = 2,
  FIRHeartbeatInfoCodeCombined = 3,
};


+ (FIRHeartbeatInfoCode)getHeartbeatCode:(NSString *)heartbeatTag;

@end

NS_ASSUME_NONNULL_END
