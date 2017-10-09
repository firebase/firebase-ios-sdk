#import "FLLRBEmptyNode.h"
#import "FLLRBValueNode.h"

@implementation FLLRBEmptyNode

@synthesize key, value, color, left, right;

- (NSString *) description {
    return [NSString stringWithFormat:@"[key=%@ val=%@ color=%@]", key, value, (color ? @"true" : @"false")];
}

+ (id)emptyNode
{
    static dispatch_once_t pred = 0;
    __strong static id _sharedObject = nil;
    dispatch_once(&pred, ^{
        _sharedObject = [[self alloc] init]; // or some other init method
    });
    return _sharedObject;
}

- (id)copyWith:(id) aKey withValue:(id) aValue withColor:(FLLRBColor*) aColor withLeft:(id<FLLRBNode>)aLeft withRight:(id<FLLRBNode>)aRight {
    return self;
}

- (id<FLLRBNode>) insertKey:(id) aKey forValue:(id)aValue withComparator:(NSComparator)aComparator {
    FLLRBValueNode* result = [[FLLRBValueNode alloc] initWithKey:aKey withValue:aValue withColor:nil withLeft:nil withRight:nil];
    return result;
}

- (id<FLLRBNode>) remove:(id) key withComparator:(NSComparator)aComparator {
    return self;
}

- (int) count {
    return 0;
}

- (BOOL) isEmpty {
    return YES;
}

- (BOOL) inorderTraversal:(BOOL (^)(id key, id value))action {
    return NO;
}

- (BOOL) reverseTraversal:(BOOL (^)(id key, id value))action {
    return NO;
}

- (id<FLLRBNode>) min {
    return self;
}

- (id) minKey {
    return nil;
}

- (id) maxKey {
    return nil;
}

- (BOOL) isRed {
    return NO;
}

- (int) check {
    return 0;
}

@end
