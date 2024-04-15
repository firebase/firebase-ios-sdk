
/*
 * Copyright 2019 Google LLC
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

#ifndef FIRESTORE_CORE_SRC_API_SETTINGS_H_
#define FIRESTORE_CORE_SRC_API_SETTINGS_H_

#include <memory>
#include <string>
#include <utility>

#include "absl/memory/memory.h"

namespace firebase {
namespace firestore {
namespace api {

class LocalCacheSettings;

/**
 * Represents settings associated with a FirestoreClient.
 *
 * PORTING NOTE: We exclude the user callback std::executor in order to avoid
 * ownership complexity.
 */
class Settings {
 public:
  // Note: a constexpr array of char (`char[]`) doesn't work with Visual Studio
  // 2015.
  static constexpr const char* DefaultHost = "firestore.googleapis.com";
  static constexpr bool DefaultSslEnabled = true;
  static constexpr bool DefaultPersistenceEnabled = true;
  static constexpr int64_t DefaultCacheSizeBytes = 100 * 1024 * 1024;
  static constexpr int64_t MinimumCacheSizeBytes = 1 * 1024 * 1024;
  static constexpr int64_t CacheSizeUnlimited = -1;

  Settings() = default;
  Settings(const Settings& other);
  Settings(Settings&& other) = default;

  Settings& operator=(const Settings& other);
  Settings& operator=(Settings&& other) = default;

  void set_host(const std::string& value) {
    host_ = value;
  }
  const std::string& host() const {
    return host_;
  }

  void set_ssl_enabled(bool value) {
    ssl_enabled_ = value;
  }
  bool ssl_enabled() const {
    return ssl_enabled_;
  }

  void set_persistence_enabled(bool value);
  bool persistence_enabled() const;

  void set_cache_size_bytes(int64_t value);
  int64_t cache_size_bytes() const;
  bool gc_enabled() const;

  const LocalCacheSettings* local_cache_settings() const;
  void set_local_cache_settings(const LocalCacheSettings& settings);

  friend bool operator==(const Settings& lhs, const Settings& rhs);

  size_t Hash() const;

 private:
  static std::unique_ptr<LocalCacheSettings> CopyCacheSettings(
      const LocalCacheSettings& settings);

  std::string host_ = DefaultHost;
  bool ssl_enabled_ = DefaultSslEnabled;
  bool persistence_enabled_ = DefaultPersistenceEnabled;
  int64_t cache_size_bytes_ = DefaultCacheSizeBytes;
  std::unique_ptr<LocalCacheSettings> cache_settings_ = nullptr;
};

class LocalCacheSettings {
  friend class Settings;

 public:
  enum class Kind { kMemory, kPersistent };
  virtual ~LocalCacheSettings() = default;
  friend bool operator==(const LocalCacheSettings& lhs,
                         const LocalCacheSettings& rhs);
  virtual size_t Hash() const = 0;

  Kind kind() const {
    return kind_;
  }

 protected:
  explicit LocalCacheSettings(Kind kind) : kind_(std::move(kind)) {
  }
  Kind kind_;
};

class PersistentCacheSettings : public LocalCacheSettings {
  friend class Settings;

 public:
  PersistentCacheSettings()
      : LocalCacheSettings(LocalCacheSettings::Kind::kPersistent),
        size_bytes_(Settings::DefaultCacheSizeBytes) {
  }
  PersistentCacheSettings WithSizeBytes(int64_t size) const;

  int64_t size_bytes() const {
    return size_bytes_;
  }

  size_t Hash() const override;

 private:
  int64_t size_bytes_;
};

class MemoryGarbageCollectorSettings {
 public:
  enum class MemoryGcKind { kEagerGc, kLruGc };
  virtual ~MemoryGarbageCollectorSettings() = default;
  friend bool operator==(const MemoryGarbageCollectorSettings& lhs,
                         const MemoryGarbageCollectorSettings& rhs);
  virtual size_t Hash() const = 0;

  MemoryGcKind kind() const {
    return kind_;
  }

 protected:
  explicit MemoryGarbageCollectorSettings(MemoryGcKind kind) : kind_(kind) {
  }
  MemoryGcKind kind_;
};

class MemoryEagerGcSettings : public MemoryGarbageCollectorSettings {
 public:
  MemoryEagerGcSettings()
      : MemoryGarbageCollectorSettings(
            MemoryGarbageCollectorSettings::MemoryGcKind::kEagerGc) {
  }
  size_t Hash() const override;
};

class MemoryLruGcSettings : public MemoryGarbageCollectorSettings {
 public:
  MemoryLruGcSettings()
      : MemoryGarbageCollectorSettings(
            MemoryGarbageCollectorSettings::MemoryGcKind::kLruGc),
        size_bytes_(Settings::DefaultCacheSizeBytes) {
  }

  size_t Hash() const override;
  MemoryLruGcSettings WithSizeBytes(int64_t size) const;

  int64_t size_bytes() const {
    return size_bytes_;
  }

 private:
  int64_t size_bytes_;
};

class MemoryCacheSettings : public LocalCacheSettings {
  friend class Settings;

 public:
  MemoryCacheSettings()
      : LocalCacheSettings(LocalCacheSettings::Kind::kMemory),
        settings_(absl::make_unique<MemoryEagerGcSettings>()) {
  }
  MemoryCacheSettings(const MemoryCacheSettings& other);
  MemoryCacheSettings& operator=(const MemoryCacheSettings& other);

  size_t Hash() const override;

  MemoryCacheSettings WithMemoryGarbageCollectorSettings(
      const MemoryGarbageCollectorSettings& settings);

  const MemoryGarbageCollectorSettings& gc_settings() const {
    return *settings_;
  }

 private:
  static std::unique_ptr<MemoryGarbageCollectorSettings> CopyMemoryGcSettings(
      const MemoryGarbageCollectorSettings& settings);

  std::unique_ptr<MemoryGarbageCollectorSettings> settings_;
};

bool operator!=(const Settings& lhs, const Settings& rhs);

bool operator==(const MemoryCacheSettings& lhs, const MemoryCacheSettings& rhs);

bool operator!=(const MemoryCacheSettings& lhs, const MemoryCacheSettings& rhs);

bool operator==(const PersistentCacheSettings& lhs,
                const PersistentCacheSettings& rhs);

bool operator!=(const PersistentCacheSettings& lhs,
                const PersistentCacheSettings& rhs);

bool operator==(const MemoryEagerGcSettings& lhs,
                const MemoryEagerGcSettings& rhs);

bool operator!=(const MemoryEagerGcSettings& lhs,
                const MemoryEagerGcSettings& rhs);

bool operator==(const MemoryLruGcSettings& lhs, const MemoryLruGcSettings& rhs);

bool operator!=(const MemoryLruGcSettings& lhs, const MemoryLruGcSettings& rhs);

}  // namespace api
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_API_SETTINGS_H_
