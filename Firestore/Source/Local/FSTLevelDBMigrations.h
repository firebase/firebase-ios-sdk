

#import <Foundation/Foundation.h>

#ifdef __cplusplus

namespace leveldb {
class DB;
}
#endif

NS_ASSUME_NONNULL_BEGIN

typedef int32_t FSTLevelDBSchemaVersion;

@interface FSTLevelDBMigrations : NSObject

+ (FSTLevelDBSchemaVersion)schemaVersionForDB:(leveldb::DB *)db;

+ (void)runMigrationsToVersion:(FSTLevelDBSchemaVersion)version onDB:(leveldb::DB *)db;

@end

NS_ASSUME_NONNULL_END