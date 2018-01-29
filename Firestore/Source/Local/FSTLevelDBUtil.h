#import <Foundation/Foundation.h>

@class FSTPBTargetGlobal;

namespace leveldb {
class DB;
struct ReadOptions;
}

NS_ASSUME_NONNULL_BEGIN

@interface FSTLevelDBUtil : NSObject

+ (const leveldb::ReadOptions)standardReadOptions;

+ (nullable FSTPBTargetGlobal *)readTargetMetadataFromDB:(leveldb::DB *)db;

@end

NS_ASSUME_NONNULL_END