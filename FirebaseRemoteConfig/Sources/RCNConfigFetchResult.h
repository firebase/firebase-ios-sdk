//
//  RCNConfigFetchResult.h
//  FirebaseRemoteConfig
//
//  Created by Yakov Manshin on 2/27/22.
//

#import <Foundation/Foundation.h>

#import "FirebaseRemoteConfig/Sources/Public/FirebaseRemoteConfig/FIRRemoteConfig.h"

NS_ASSUME_NONNULL_BEGIN

@interface RCNConfigFetchResult : NSObject

@property(nonatomic, readonly) FIRRemoteConfigFetchStatus status;
@property(nonatomic, readonly, nullable) NSError *error;

+ (instancetype)resultWithStatus:(FIRRemoteConfigFetchStatus)status error:(nullable NSError *)error;

@end

NS_ASSUME_NONNULL_END
