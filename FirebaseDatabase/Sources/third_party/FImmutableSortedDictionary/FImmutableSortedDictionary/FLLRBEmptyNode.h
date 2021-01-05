#import <Foundation/Foundation.h>
#import "FirebaseDatabase/Sources/third_party/FImmutableSortedDictionary/FImmutableSortedDictionary/FLLRBNode.h"

@interface FLLRBEmptyNode : NSObject <FLLRBNode>

+ (id)emptyNode;

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

@property (nonatomic, strong) id key;
@property (nonatomic, strong) id value;
@property (nonatomic, strong) FLLRBColor* color;
@property (nonatomic, strong) id<FLLRBNode> left;
@property (nonatomic, strong) id<FLLRBNode> right;

@end
