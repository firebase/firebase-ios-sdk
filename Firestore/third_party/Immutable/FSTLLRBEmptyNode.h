#import <Foundation/Foundation.h>

#import "Firestore/third_party/Immutable/FSTLLRBNode.h"

NS_ASSUME_NONNULL_BEGIN

@interface FSTLLRBEmptyNode : NSObject <FSTLLRBNode>
+ (instancetype)emptyNode;
@end

NS_ASSUME_NONNULL_END
