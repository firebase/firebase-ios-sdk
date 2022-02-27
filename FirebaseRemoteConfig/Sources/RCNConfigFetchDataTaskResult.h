//
//  RCNConfigFetchDataTaskResult.h
//  FirebaseRemoteConfig
//
//  Created by Yakov Manshin on 2/27/22.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface RCNConfigFetchDataTaskResult : NSObject

@property(nonatomic, readonly, nullable) NSData *data;
@property(nonatomic, readonly, nullable) NSURLResponse *response;
@property(nonatomic, readonly, nullable) NSError *error;

+ (instancetype)resultWithData:(nullable NSData *)data
                      response:(nullable NSURLResponse *)response
                         error:(nullable NSError *)error;

@end

NS_ASSUME_NONNULL_END
