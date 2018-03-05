/*
 * Copyright 2018 Google
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#ifndef FIRESTORE_FSTLEVELDBTRANSACTION_H
#define FIRESTORE_FSTLEVELDBTRANSACTION_H

#include <map>
#include <set>
#include <leveldb/db.h>


#ifdef __OBJC__
@class GPBMessage;
#endif

namespace firebase {
namespace firestore {
namespace local {

typedef std::map<std::string, leveldb::Slice> Mutations;
typedef std::set<std::string> Deletions;

class LevelDBTransaction {
 public:
  LevelDBTransaction(std::shared_ptr<leveldb::DB> db,
                     const leveldb::ReadOptions& readOptions,
                     const leveldb::WriteOptions& writeOptions);

  void Delete(const std::string& key);
#ifdef __OBJC__
  void Put(const std::string& key, GPBMessage* message);
#endif
  void Put(const std::string& key, const leveldb::Slice& value);

  leveldb::Status Get(const std::string& key, std::string* value);

  class Iterator /*: leveldb::Iterator*/ {
   public:
    Iterator(LevelDBTransaction* txn);
    void Seek(const std::string& key);
    bool Valid();
    void Next();
    std::string key();
    leveldb::Slice value();

   private:
    std::unique_ptr<leveldb::Iterator> ldb_iter_;
    Mutations* mutations_;
    Deletions* deletions_;
    std::unique_ptr<Mutations::iterator> mutations_iter_;
    bool is_mutation();
    void AdvanceLDB();
  };

  Iterator* NewIterator();

  void Commit();

 private:
  std::shared_ptr<leveldb::DB> db_;
  Mutations mutations_;
  Deletions deletions_;
  leveldb::WriteOptions writeOptions_;
  leveldb::ReadOptions readOptions_;
};

}  // namespace local
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_FSTLEVELDBTRANSACTION_H
