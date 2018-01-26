#import "Firestore/Example/Tests/Local/FSTLRUGarbageCollectorTests.h"

#import "Firestore/Example/Tests/Local/FSTPersistenceTestHelpers.h"

NS_ASSUME_NONNULL_BEGIN

@interface FSTLevelDBLRUGarbageCollectorTests : FSTLRUGarbageCollectorTests
@end

@implementation FSTLevelDBLRUGarbageCollectorTests

- (id<FSTPersistence>)newPersistence {
  return [FSTPersistenceTestHelpers levelDBPersistence];
}

@end

NS_ASSUME_NONNULL_END