#import <Foundation/Foundation.h>

#import "Firestore/third_party/Immutable/FSTLLRBNode.h"

NS_ASSUME_NONNULL_BEGIN

@interface FSTLLRBValueNode : NSObject <FSTLLRBNode>

- (id)init __attribute__((
    unavailable("Use initWithKey:withValue:withColor:withLeft:withRight: instead.")));

- (instancetype)initWithKey:(nullable id)key
                  withValue:(nullable id)value
                  withColor:(FSTLLRBColor)color
                   withLeft:(nullable id<FSTLLRBNode>)left
                  withRight:(nullable id<FSTLLRBNode>)right NS_DESIGNATED_INITIALIZER;

@property(nonatomic, assign, readonly) FSTLLRBColor color;
@property(nonatomic, strong, readonly, nullable) id key;
@property(nonatomic, strong, readonly, nullable) id value;
@property(nonatomic, strong, readonly, nullable) id<FSTLLRBNode> right;

// This property cannot be readonly, because it is set when building the tree.
// TODO(klimt): Find a way to build the tree without mutating this.
@property(nonatomic, strong, nullable) id<FSTLLRBNode> left;

@end

NS_ASSUME_NONNULL_END
