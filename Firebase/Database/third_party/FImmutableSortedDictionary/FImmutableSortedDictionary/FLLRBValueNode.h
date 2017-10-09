#import <Foundation/Foundation.h>
#import "FLLRBNode.h"

@interface FLLRBValueNode : NSObject <FLLRBNode>


- (id)initWithKey:(id) key withValue:(id) value withColor:(FLLRBColor*) color withLeft:(id<FLLRBNode>)left withRight:(id<FLLRBNode>)right;
- (id)copyWith:(id) aKey withValue:(id) aValue withColor:(FLLRBColor*) aColor withLeft:(id<FLLRBNode>)aLeft withRight:(id<FLLRBNode>)aRight;
- (id<FLLRBNode>) insertKey:(id) aKey forValue:(id)aValue withComparator:(NSComparator)aComparator;
- (id<FLLRBNode>) remove:(id) aKey withComparator:(NSComparator)aComparator;
- (int) count;
- (BOOL) isEmpty;
- (BOOL) inorderTraversal:(BOOL (^)(id key, id value))action;
- (BOOL) reverseTraversal:(BOOL (^)(id key, id value))action;
- (id<FLLRBNode>) min;
- (id) minKey;
- (id) maxKey;
- (BOOL) isRed;
- (int) check;

- (BOOL) checkMaxDepth;

@property (nonatomic, strong) id key;
@property (nonatomic, strong) id value;
@property (nonatomic, strong) FLLRBColor* color;
@property (nonatomic, strong) id<FLLRBNode> left;
@property (nonatomic, strong) id<FLLRBNode> right;

@end
