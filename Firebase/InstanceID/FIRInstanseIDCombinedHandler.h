#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FIRInstanseIDCombinedHandler<ResultType> : NSObject

- (void)addHandler:(void (^)(ResultType _Nullable result, NSError  * _Nullable error))handler;
- (void (^)(ResultType _Nullable result, NSError * _Nullable error))combinedHandler;

@end

NS_ASSUME_NONNULL_END
