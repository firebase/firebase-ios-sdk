#import "Firestore/Source/Local/FSTLevelDBUtil.h"

#import <leveldb/db.h>

#import "Firestore/Protos/objc/firestore/local/Target.pbobjc.h"
#import "Firestore/Source/Local/FSTLevelDBKey.h"
#import "Firestore/Source/Util/FSTAssert.h"

using leveldb::DB;
using leveldb::ReadOptions;
using leveldb::Slice;
using leveldb::Status;
using leveldb::WriteOptions;

@implementation FSTLevelDBUtil

+ (const ReadOptions)standardReadOptions {
  ReadOptions options;
  options.verify_checksums = true;
  return options;
}

+ (FSTPBTargetGlobal *)readTargetMetadataFromDB:(DB *)db {
  std::string key = [FSTLevelDBTargetGlobalKey key];
  std::string value;
  Status status = db->Get([FSTLevelDBUtil standardReadOptions], key, &value);
  if (status.IsNotFound()) {
    return nil;
  } else if (!status.ok()) {
    FSTFail(@"metadataForKey: failed loading key %s with status: %s", key.c_str(),
            status.ToString().c_str());
  }

  NSData *data =
          [[NSData alloc] initWithBytesNoCopy:(void *)value.data() length:value.size() freeWhenDone:NO];

  NSError *error;
  FSTPBTargetGlobal *proto = [FSTPBTargetGlobal parseFromData:data error:&error];
  if (!proto) {
    FSTFail(@"FSTPBTargetGlobal failed to parse: %@", error);
  }

  return proto;
}

@end
