#import "Immutable/FSTLLRBValueNode.h"

#import <Foundation/Foundation.h>

/** Extra methods exposed only for testing. */
@interface FSTLLRBValueNode (Test)
- (id<FSTLLRBNode>)rotateLeft;
- (id<FSTLLRBNode>)rotateRight;
- (BOOL)checkMaxDepth;
@end
