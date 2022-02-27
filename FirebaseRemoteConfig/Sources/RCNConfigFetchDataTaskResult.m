//
//  RCNConfigFetchDataTaskResult.m
//  FirebaseRemoteConfig
//
//  Created by Yakov Manshin on 2/27/22.
//

#import "RCNConfigFetchDataTaskResult.h"

NS_ASSUME_NONNULL_BEGIN

@implementation RCNConfigFetchDataTaskResult

+ (instancetype)resultWithData:(nullable NSData *)data
                      response:(nullable NSURLResponse *)response
                         error:(nullable NSError *)error {
  RCNConfigFetchDataTaskResult *result = [[RCNConfigFetchDataTaskResult alloc] init];
  result->_data = data;
  result->_response = response;
  result->_error = error;

  return result;
}

@end

NS_ASSUME_NONNULL_END
