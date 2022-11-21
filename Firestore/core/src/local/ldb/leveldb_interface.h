/*
 * Copyright 2022 Google
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

#ifndef FIRESTORE_CORE_SRC_LOCAL_LDB_LEVELDB_INTERFACE_H_
#define FIRESTORE_CORE_SRC_LOCAL_LDB_LEVELDB_INTERFACE_H_

#include <string>
#include <utility>

#include "absl/strings/string_view.h"
#include "leveldb/db.h"
#include "leveldb/options.h"
#include "leveldb/slice.h"
#include "leveldb/write_batch.h"

#include <pqxx/pqxx>

namespace firebase {
namespace firestore {
namespace local {
namespace ldb {

#ifdef PG_PERSISTENCE

class Slice {
 public:
  // Create an empty slice.
  Slice() : data_(""), size_(0) {
  }

  // Create a slice that refers to d[0,n-1].
  Slice(const char* d, size_t n) : data_(d), size_(n) {
  }

  // Create a slice that refers to the contents of "s"
  Slice(const std::string& s) : data_(s.data()), size_(s.size()) {
  }

  // Create a slice that refers to s[0,strlen(s)-1]
  Slice(const char* s) : data_(s), size_(strlen(s)) {
  }

  // Intentionally copyable.
  Slice(const Slice&) = default;
  Slice& operator=(const Slice&) = default;

  // Return a pointer to the beginning of the referenced data
  const char* data() const {
    return data_;
  }

  // Return the length (in bytes) of the referenced data
  size_t size() const {
    return size_;
  }

  // Return true iff the length of the referenced data is zero
  bool empty() const {
    return size_ == 0;
  }

  // Return the ith byte in the referenced data.
  // REQUIRES: n < size()
  char operator[](size_t n) const {
    assert(n < size());
    return data_[n];
  }

  // Change this slice to refer to an empty array
  void clear() {
    data_ = "";
    size_ = 0;
  }

  // Drop the first "n" bytes from this slice.
  void remove_prefix(size_t n) {
    assert(n <= size());
    data_ += n;
    size_ -= n;
  }

  // Return a string that contains the copy of the referenced data.
  std::string ToString() const {
    return std::string(data_, size_);
  }

  // Three-way comparison.  Returns value:
  //   <  0 iff "*this" <  "b",
  //   == 0 iff "*this" == "b",
  //   >  0 iff "*this" >  "b"
  int compare(const Slice& b) const;

  // Return true iff "x" is a prefix of "*this"
  bool starts_with(const Slice& x) const {
    return ((size_ >= x.size_) && (memcmp(data_, x.data_, x.size_) == 0));
  }

 private:
  const char* data_;
  size_t size_;
};

inline bool operator==(const Slice& x, const Slice& y) {
  return ((x.size() == y.size()) &&
          (memcmp(x.data(), y.data(), x.size()) == 0));
}

inline bool operator!=(const Slice& x, const Slice& y) {
  return !(x == y);
}

inline int Slice::compare(const Slice& b) const {
  const size_t min_len = (size_ < b.size_) ? size_ : b.size_;
  int r = memcmp(data_, b.data_, min_len);
  if (r == 0) {
    if (size_ < b.size_)
      r = -1;
    else if (size_ > b.size_)
      r = +1;
  }
  return r;
}

class Status {
 public:
  // Create a success status.
  Status() noexcept : state_(nullptr) {
  }
  ~Status() {
    delete[] state_;
  }

  Status(const Status& rhs);
  Status& operator=(const Status& rhs);

  Status(Status&& rhs) noexcept : state_(rhs.state_) {
    rhs.state_ = nullptr;
  }
  Status& operator=(Status&& rhs) noexcept;

  // Return a success status.
  static Status OK() {
    return Status();
  }

  // Return error status of an appropriate type.
  static Status NotFound(const Slice& msg, const Slice& msg2 = Slice()) {
    return Status(kNotFound, msg, msg2);
  }
  static Status Corruption(const Slice& msg, const Slice& msg2 = Slice()) {
    return Status(kCorruption, msg, msg2);
  }
  static Status NotSupported(const Slice& msg, const Slice& msg2 = Slice()) {
    return Status(kNotSupported, msg, msg2);
  }
  static Status InvalidArgument(const Slice& msg, const Slice& msg2 = Slice()) {
    return Status(kInvalidArgument, msg, msg2);
  }
  static Status IOError(const Slice& msg, const Slice& msg2 = Slice()) {
    return Status(kIOError, msg, msg2);
  }

  // Returns true iff the status indicates success.
  bool ok() const {
    return (state_ == nullptr);
  }

  // Returns true iff the status indicates a NotFound error.
  bool IsNotFound() const {
    return code() == kNotFound;
  }

  // Returns true iff the status indicates a Corruption error.
  bool IsCorruption() const {
    return code() == kCorruption;
  }

  // Returns true iff the status indicates an IOError.
  bool IsIOError() const {
    return code() == kIOError;
  }

  // Returns true iff the status indicates a NotSupportedError.
  bool IsNotSupportedError() const {
    return code() == kNotSupported;
  }

  // Returns true iff the status indicates an InvalidArgument.
  bool IsInvalidArgument() const {
    return code() == kInvalidArgument;
  }

  // Return a string representation of this status suitable for printing.
  // Returns the string "OK" for success.
  std::string ToString() const;

 private:
  enum Code {
    kOk = 0,
    kNotFound = 1,
    kCorruption = 2,
    kNotSupported = 3,
    kInvalidArgument = 4,
    kIOError = 5
  };

  Code code() const {
    return (state_ == nullptr) ? kOk : static_cast<Code>(state_[4]);
  }

  Status(Code code, const Slice& msg, const Slice& msg2);
  static const char* CopyState(const char* s);

  // OK status has a null state_.  Otherwise, state_ is a new[] array
  // of the following form:
  //    state_[0..3] == length of message
  //    state_[4]    == code
  //    state_[5..]  == message
  const char* state_;
};

inline Status::Status(const Status& rhs) {
  state_ = (rhs.state_ == nullptr) ? nullptr : CopyState(rhs.state_);
}
inline Status& Status::operator=(const Status& rhs) {
  // The following condition catches both aliasing (when this == &rhs),
  // and the common case where both rhs and *this are ok.
  if (state_ != rhs.state_) {
    delete[] state_;
    state_ = (rhs.state_ == nullptr) ? nullptr : CopyState(rhs.state_);
  }
  return *this;
}
inline Status& Status::operator=(Status&& rhs) noexcept {
  std::swap(state_, rhs.state_);
  return *this;
}

enum CompressionType {
  // NOTE: do not change the values of existing entries, as these are
  // part of the persistent format on disk.
  kNoCompression = 0x0,
  kSnappyCompression = 0x1
};

// Options to control the behavior of a database (passed to DB::Open)
struct Options {
  // Create an Options object with default values for all fields.
  Options();

  // If true, the database will be created if it is missing.
  bool create_if_missing = false;

  // If true, an error is raised if the database already exists.
  bool error_if_exists = false;

  CompressionType compression = kSnappyCompression;
};

// Options that control read operations
struct ReadOptions {
  ReadOptions() = default;

  // If true, all data read from underlying storage will be
  // verified against corresponding checksums.
  bool verify_checksums = false;

  // Should the data read for this iteration be cached in memory?
  // Callers may wish to set this field to false for bulk scans.
  bool fill_cache = true;
};

// Options that control write operations
struct WriteOptions {
  WriteOptions() = default;

  bool sync = false;
};

class WriteBatch {
 public:
  class Handler {
   public:
    virtual ~Handler();
    virtual void Put(const Slice& key, const Slice& value) = 0;
    virtual void Delete(const Slice& key) = 0;
  };

  WriteBatch();

  // Intentionally copyable.
  WriteBatch(const WriteBatch&) = default;
  WriteBatch& operator=(const WriteBatch&) = default;

  ~WriteBatch();

  // Store the mapping "key->value" in the database.
  void Put(const Slice& key, const Slice& value);

  // If the database contains a mapping for "key", erase it.  Else do nothing.
  void Delete(const Slice& key);

  // Clear all updates buffered in this batch.
  void Clear();

  // The size of the database changes caused by this batch.
  //
  // This number is tied to implementation details, and may change across
  // releases. It is intended for LevelDB usage metrics.
  size_t ApproximateSize() const;

  // Copies the operations in "source" to this batch.
  //
  // This runs in O(source size) time. However, the constant factor is better
  // than calling Iterate() over the source batch with a Handler that replicates
  // the operations into this batch.
  void Append(const WriteBatch& source);

  // Support for iterating over the contents of a batch.
  Status Iterate(Handler* handler) const;

 private:
  std::string rep_;  // See comment in write_batch.cc for the format of rep_
};

class Iterator {
 public:
  Iterator();

  Iterator(const Iterator&) = delete;
  Iterator& operator=(const Iterator&) = delete;

  ~Iterator();

  // An iterator is either positioned at a key/value pair, or
  // not valid.  This method returns true iff the iterator is valid.
  bool Valid() const;

  // Position at the first key in the source.  The iterator is Valid()
  // after this call iff the source is not empty.
  void SeekToFirst();

  // Position at the last key in the source.  The iterator is
  // Valid() after this call iff the source is not empty.
  void SeekToLast();

  // Position at the first key in the source that is at or past target.
  // The iterator is Valid() after this call iff the source contains
  // an entry that comes at or past target.
  void Seek(const Slice& target);

  // Moves to the next entry in the source.  After this call, Valid() is
  // true iff the iterator was not positioned at the last entry in the source.
  // REQUIRES: Valid()
  void Next();

  // Moves to the previous entry in the source.  After this call, Valid() is
  // true iff the iterator was not positioned at the first entry in source.
  // REQUIRES: Valid()
  void Prev();

  // Return the key for the current entry.  The underlying storage for
  // the returned slice is valid only until the next modification of
  // the iterator.
  // REQUIRES: Valid()
  Slice key();

  // Return the value for the current entry.  The underlying storage for
  // the returned slice is valid only until the next modification of
  // the iterator.
  // REQUIRES: Valid()
  Slice value();

  // If an error has occurred, return it.  Else return an ok status.
  Status status();

  // Clients are allowed to register function/arg1/arg2 triples that
  // will be invoked when this iterator is destroyed.
  //
  // Note that unlike all of the preceding methods, this method is
  // not abstract and therefore clients should not override it.
  using CleanupFunction = void (*)(void* arg1, void* arg2);
  void RegisterCleanup(CleanupFunction function, void* arg1, void* arg2);

 private:
  // Cleanup functions are stored in a single-linked list.
  // The list's head node is inlined in the iterator.
  struct CleanupNode {
    // True if the node is not used. Only head nodes might be unused.
    bool IsEmpty() const {
      return function == nullptr;
    }
    // Invokes the cleanup function.
    void Run() {
      assert(function != nullptr);
      (*function)(arg1, arg2);
    }

    // The head node is used if the function pointer is not null.
    CleanupFunction function;
    void* arg1;
    void* arg2;
    CleanupNode* next;
  };
  CleanupNode cleanup_head_;
};

class DB {
 public:
  static Status Open(const Options& options,
                     const std::string& name,
                     DB** dbptr);

  DB() = default;

  DB(const DB&) = delete;
  DB& operator=(const DB&) = delete;

  ~DB();

  Status Put(const WriteOptions& options, const Slice& key, const Slice& value);

  Status Delete(const WriteOptions& options, const Slice& key);

  Status Write(const WriteOptions& options, WriteBatch* updates);

  Status Get(const ReadOptions& options, const Slice& key, std::string* value);

  Iterator* NewIterator(const ReadOptions& options);

  bool GetProperty(const Slice& property, std::string* value);
};

#else

using DB = ::leveldb::DB;
using Slice = ::leveldb::Slice;
using Iterator = ::leveldb::Iterator;
using Options = ::leveldb::Options;
using ReadOptions = ::leveldb::ReadOptions;
using WriteOptions = ::leveldb::WriteOptions;
using WriteBatch = ::leveldb::WriteBatch;
using Status = ::leveldb::Status;

#endif

}  // namespace ldb
}  // namespace local
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_LOCAL_LDB_LEVELDB_INTERFACE_H_
