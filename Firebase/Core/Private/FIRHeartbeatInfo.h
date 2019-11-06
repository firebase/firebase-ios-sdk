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
  FIRHeartbeatInfoCodeNONE = 0,
  FIRHeartbeatInfoCodeSDK = 1,
  FIRHeartbeatInfoCodeGLOBAL = 2,
  FIRHeartbeatInfoCodeCOMBINED = 3,
};

+ (FIRHeartbeatInfoCode)heartbeatCodeForTag:(NSString *)heartbeatTag;

@end

NS_ASSUME_NONNULL_END
