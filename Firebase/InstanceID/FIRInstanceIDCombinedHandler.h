#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * A generic class to combine several handler blocks into a single block in a thread-safe manner
 */
@interface FIRInstanceIDCombinedHandler<ResultType> : NSObject

- (void)addHandler:(void (^)(ResultType _Nullable result, NSError* _Nullable error))handler;
- (void (^)(ResultType _Nullable result, NSError* _Nullable error))combinedHandler;

@end

NS_ASSUME_NONNULL_END
