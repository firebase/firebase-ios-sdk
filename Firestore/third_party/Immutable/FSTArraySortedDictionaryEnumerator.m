#import "Firestore/third_party/Immutable/FSTArraySortedDictionaryEnumerator.h"

NS_ASSUME_NONNULL_BEGIN

// clang-format off
// For some reason, clang-format messes this line up...
@interface FSTArraySortedDictionaryEnumerator<KeyType, ValueType> ()
@property(nonatomic, assign) int pos;
@property(nonatomic, assign) int start;
@property(nonatomic, assign) int end;
@property(nonatomic, assign) BOOL reverse;
@property(nonatomic, strong) NSArray<KeyType> *keys;
@end
// clang-format on

@implementation FSTArraySortedDictionaryEnumerator

- (id)initWithKeys:(NSArray *)keys startPos:(int)start endPos:(int)end isReverse:(BOOL)reverse {
  self = [super init];
  if (self != nil) {
    _keys = keys;
    _start = start;
    _end = end;
    _pos = start;
    _reverse = reverse;
  }
  return self;
}

- (nullable id)nextObject {
  if (self.pos < 0 || self.pos >= self.keys.count) {
    return nil;
  }
  if (self.reverse) {
    if (self.pos <= self.end) {
      return nil;
    }
  } else {
    if (self.pos >= self.end) {
      return nil;
    }
  }
  int pos = self.pos;
  if (self.reverse) {
    self.pos--;
  } else {
    self.pos++;
  }
  return self.keys[pos];
}

@end

NS_ASSUME_NONNULL_END
