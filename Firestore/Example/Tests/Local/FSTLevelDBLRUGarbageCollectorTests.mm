#import <Firestore/Source/Local/FSTLevelDB.h>
#import "Firestore/Example/Tests/Local/FSTLRUGarbageCollectorTests.h"
#import "Firestore/Example/Tests/Local/FSTPersistenceTestHelpers.h"
#import "Firestore/Source/Local/FSTLRUGarbageCollector.h"

NS_ASSUME_NONNULL_BEGIN

@interface FSTLevelDBLRUGarbageCollectorTests : FSTLRUGarbageCollectorTests
@end

@implementation FSTLevelDBLRUGarbageCollectorTests

- (id<FSTPersistence>)newPersistence {
  return [FSTPersistenceTestHelpers levelDBPersistence];
}

@end

NS_ASSUME_NONNULL_END