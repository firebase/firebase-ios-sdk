#import "FLLRBValueNode.h"
#import "FLLRBEmptyNode.h"

@implementation FLLRBValueNode

@synthesize key, value, color, left, right;

- (NSString *) description {
    return [NSString stringWithFormat:@"[key=%@ val=%@ color=%@]", key, value, (color ? @"true" : @"false")];
}

- (id)initWithKey:(__unsafe_unretained id) aKey withValue:(__unsafe_unretained id) aValue withColor:(__unsafe_unretained FLLRBColor*) aColor withLeft:(__unsafe_unretained id<FLLRBNode>)aLeft withRight:(__unsafe_unretained id<FLLRBNode>)aRight
{
    self = [super init];
    if (self) {
        self.key = aKey;
        self.value = aValue;
        self.color = aColor != nil ? aColor : RED;
        self.left = aLeft != nil ? aLeft : [FLLRBEmptyNode emptyNode];
        self.right = aRight != nil ? aRight : [FLLRBEmptyNode emptyNode];
    }
    return self;
}

- (id)copyWith:(__unsafe_unretained id) aKey withValue:(__unsafe_unretained id) aValue withColor:(__unsafe_unretained FLLRBColor*) aColor withLeft:(__unsafe_unretained id<FLLRBNode>)aLeft withRight:(__unsafe_unretained id<FLLRBNode>)aRight {
    return [[FLLRBValueNode alloc] initWithKey:(aKey != nil) ? aKey : self.key
                                     withValue:(aValue != nil) ? aValue : self.value
                                     withColor:(aColor != nil) ? aColor : self.color
                                      withLeft:(aLeft != nil) ? aLeft : self.left
                                     withRight:(aRight != nil) ? aRight : self.right];
}

- (int) count {
    return [self.left count] + 1 + [self.right count];
}

- (BOOL) isEmpty {
    return NO;
}

/**
* Early terminates if aciton returns YES.
* @return The first truthy value returned by action, or the last falsey value returned by action.
*/
- (BOOL) inorderTraversal:(BOOL (^)(id key, id value))action {
    return [self.left inorderTraversal:action] ||
        action(self.key, self.value) ||
    [self.right inorderTraversal:action];
}

- (BOOL) reverseTraversal:(BOOL (^)(id key, id value))action {
 return [self.right reverseTraversal:action] ||
        action(self.key, self.value) ||
    [self.left reverseTraversal:action];
}

- (id<FLLRBNode>) min {
    if([self.left isEmpty]) {
        return self;
    }
    else {
        return [self.left min];
    }
}

- (id) minKey {
    return [[self min] key];
}

- (id) maxKey {
    if([self.right isEmpty]) {
        return self.key;
    }
    else {
        return [self.right maxKey];
    }
}

- (id<FLLRBNode>) insertKey:(__unsafe_unretained id) aKey forValue:(__unsafe_unretained id)aValue withComparator:(NSComparator)aComparator {
    NSComparisonResult cmp = aComparator(aKey, self.key);
    FLLRBValueNode* n = self;

    if(cmp == NSOrderedAscending) {
        n = [n copyWith:nil withValue:nil withColor:nil withLeft:[n.left insertKey:aKey forValue:aValue withComparator:aComparator] withRight:nil];
    }
    else if(cmp == NSOrderedSame) {
        n = [n copyWith:nil withValue:aValue withColor:nil withLeft:nil withRight:nil];
    }
    else {
        n = [n copyWith:nil withValue:nil withColor:nil withLeft:nil withRight:[n.right insertKey:aKey forValue:aValue withComparator:aComparator]];
    }

    return [n fixUp];
}

- (id<FLLRBNode>) removeMin {

    if([self.left isEmpty]) {
        return [FLLRBEmptyNode emptyNode];
    }

    FLLRBValueNode* n = self;
    if(! [n.left isRed] && ! [n.left.left isRed]) {
        n = [n moveRedLeft];
    }

    n = [n copyWith:nil withValue:nil withColor:nil withLeft:[(FLLRBValueNode*)n.left removeMin] withRight:nil];
    return [n fixUp];
}


- (id<FLLRBNode>) fixUp {
    FLLRBValueNode* n = self;
    if([n.right isRed] && ! [n.left isRed]) n = [n rotateLeft];
    if([n.left isRed] && [n.left.left isRed]) n = [n rotateRight];
    if([n.left isRed] && [n.right isRed]) n = [n colorFlip];
    return n;
}

- (FLLRBValueNode*) moveRedLeft {
    FLLRBValueNode* n = [self colorFlip];
    if([n.right.left isRed]) {
        n = [n copyWith:nil withValue:nil withColor:nil withLeft:nil withRight:[(FLLRBValueNode*)n.right rotateRight]];
        n = [n rotateLeft];
        n = [n colorFlip];
    }
    return n;
}

- (FLLRBValueNode*) moveRedRight {
    FLLRBValueNode* n = [self colorFlip];
    if([n.left.left isRed]) {
        n = [n rotateRight];
        n = [n colorFlip];
    }
    return n;
}

- (id<FLLRBNode>) rotateLeft {
    id<FLLRBNode> nl = [self copyWith:nil withValue:nil withColor:RED withLeft:nil withRight:self.right.left];
    return [self.right copyWith:nil withValue:nil withColor:self.color withLeft:nl withRight:nil];;
}

- (id<FLLRBNode>) rotateRight {
    id<FLLRBNode> nr = [self copyWith:nil withValue:nil withColor:RED withLeft:self.left.right withRight:nil];
    return [self.left copyWith:nil withValue:nil withColor:self.color withLeft:nil withRight:nr];
}

- (id<FLLRBNode>) colorFlip {
    id<FLLRBNode> nleft = [self.left copyWith:nil withValue:nil withColor:[NSNumber numberWithBool:![self.left.color boolValue]] withLeft:nil withRight:nil];
    id<FLLRBNode> nright = [self.right copyWith:nil withValue:nil withColor:[NSNumber numberWithBool:![self.right.color boolValue]] withLeft:nil withRight:nil];

    return [self copyWith:nil withValue:nil withColor:[NSNumber numberWithBool:![self.color boolValue]] withLeft:nleft withRight:nright];
}

- (id<FLLRBNode>) remove:(__unsafe_unretained id) aKey withComparator:(NSComparator)comparator {
    id<FLLRBNode> smallest;
    FLLRBValueNode* n = self;

    if(comparator(aKey, n.key) == NSOrderedAscending) {
        if(![n.left isEmpty] && ![n.left isRed] && ![n.left.left isRed]) {
            n = [n moveRedLeft];
        }
        n = [n copyWith:nil withValue:nil withColor:nil withLeft:[n.left remove:aKey withComparator:comparator] withRight:nil];
    }
    else {
        if([n.left isRed]) {
            n = [n rotateRight];
        }

        if(![n.right isEmpty] && ![n.right isRed] && ![n.right.left isRed]) {
            n = [n moveRedRight];
        }

        if(comparator(aKey, n.key) == NSOrderedSame) {
            if([n.right isEmpty]) {
                return [FLLRBEmptyNode emptyNode];
            }
            else {
                smallest = [n.right min];
                n = [n copyWith:smallest.key withValue:smallest.value withColor:nil withLeft:nil withRight:[(FLLRBValueNode*)n.right removeMin]];
            }
        }
        n = [n copyWith:nil withValue:nil withColor:nil withLeft:nil withRight:[n.right remove:aKey withComparator:comparator]];
    }
    return [n fixUp];
}

- (BOOL) isRed {
    return [self.color boolValue];
}

- (BOOL) checkMaxDepth {
    int blackDepth = [self check];
    if(pow(2.0, blackDepth) <= ([self count] + 1)) {
        return YES;
    }
    else {
        return NO;
    }
}

- (int) check {
    int blackDepth = 0;

    if([self isRed] && [self.left isRed]) {
        @throw [[NSException alloc] initWithName:@"check" reason:@"Red node has a red child" userInfo:nil];
    }

    if([self.right isRed]) {
        @throw [[NSException alloc] initWithName:@"check" reason:@"Right child is red" userInfo:nil];
    }

    blackDepth = [self.left check];
//    NSLog(err);
    if(blackDepth != [self.right check]) {
        NSString* err = [NSString stringWithFormat:@"(%@ -> %@)blackDepth: %d ; self.right check: %d", self.value, [self.color boolValue] ? @"red" : @"black", blackDepth, [self.right check]];
//        return 10;
        @throw [[NSException alloc] initWithName:@"check" reason:err userInfo:nil];
    }
    else {
                int ret = blackDepth + ([self isRed] ? 0 : 1);
//        NSLog(@"black depth is: %d; other is: %d, ret is: %d", blackDepth, ([self isRed] ? 0 : 1), ret);
        return ret;
    }
}


@end
