//
//  RCNConfigFetchResult.m
//  FirebaseRemoteConfig
//
//  Created by Yakov Manshin on 2/27/22.
//

#import "FirebaseRemoteConfig/Sources/RCNConfigFetchResult.h"

NS_ASSUME_NONNULL_BEGIN

@implementation RCNConfigFetchResult

+ (instancetype)resultWithStatus:(FIRRemoteConfigFetchStatus)status
                           error:(nullable NSError *)error {
  RCNConfigFetchResult *result = [[self alloc] init];
  result->_status = status;
  result->_error = error;

  return result;
}

@end

NS_ASSUME_NONNULL_END
