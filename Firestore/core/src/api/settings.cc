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

#include "Firestore/core/src/api/settings.h"
#include <cstddef>
#include <memory>

#include "Firestore/core/src/util/hard_assert.h"
#include "Firestore/core/src/util/hashing.h"
#include "absl/memory/memory.h"

namespace firebase {
namespace firestore {
namespace api {

constexpr const char* Settings::DefaultHost;
constexpr bool Settings::DefaultSslEnabled;
constexpr bool Settings::DefaultPersistenceEnabled;
constexpr int64_t Settings::DefaultCacheSizeBytes;
constexpr int64_t Settings::MinimumCacheSizeBytes;

Settings::Settings(const Settings& other)
    : host_(other.host_),
      ssl_enabled_(other.ssl_enabled_),
      persistence_enabled_(other.persistence_enabled_),
      cache_size_bytes_(other.cache_size_bytes_) {
  if (other.cache_settings_ != nullptr) {
    cache_settings_ = CopyCacheSettings(*other.cache_settings_);
  }
}

Settings& Settings::operator=(const Settings& other) {
  if (this == &other) {
    return *this;
  }

  host_ = other.host_;
  ssl_enabled_ = other.ssl_enabled_;
  persistence_enabled_ = other.persistence_enabled_;
  cache_size_bytes_ = other.cache_size_bytes_;
  if (other.cache_settings_ != nullptr) {
    cache_settings_ = CopyCacheSettings(*other.cache_settings_);
  }
  return *this;
}

std::unique_ptr<LocalCacheSettings> Settings::CopyCacheSettings(
    const LocalCacheSettings& settings) {
  if (settings.kind_ == LocalCacheSettings::Kind::kMemory) {
    return absl::make_unique<MemoryCacheSettings>(
        static_cast<const MemoryCacheSettings&>(settings));
  } else if (settings.kind_ == LocalCacheSettings::Kind::kPersistent) {
    return absl::make_unique<PersistentCacheSettings>(
        static_cast<const PersistentCacheSettings&>(settings));
  }
  UNREACHABLE();
}

std::unique_ptr<MemoryGarbageCollectorSettings>
MemoryCacheSettings::CopyMemoryGcSettings(
    const MemoryGarbageCollectorSettings& settings) {
  if (settings.kind() ==
      MemoryGarbageCollectorSettings::MemoryGcKind::kEagerGc) {
    return absl::make_unique<MemoryEagerGcSettings>(
        static_cast<const MemoryEagerGcSettings&>(settings));
  } else if (settings.kind() ==
             MemoryGarbageCollectorSettings::MemoryGcKind::kLruGc) {
    return absl::make_unique<MemoryLruGcSettings>(
        static_cast<const MemoryLruGcSettings&>(settings));
  }
  UNREACHABLE();
}

MemoryCacheSettings::MemoryCacheSettings(const MemoryCacheSettings& other)
    : LocalCacheSettings(other.kind()),
      settings_(CopyMemoryGcSettings(*other.settings_)) {
}

MemoryCacheSettings& MemoryCacheSettings::operator=(
    const MemoryCacheSettings& other) {
  if (this == &other) {
    return *this;
  }

  LocalCacheSettings::operator=(other);
  settings_ = CopyMemoryGcSettings(*other.settings_);
  return *this;
}

MemoryLruGcSettings MemoryLruGcSettings::WithSizeBytes(int64_t size) const {
  MemoryLruGcSettings new_settings{*this};
  new_settings.size_bytes_ = size;
  return new_settings;
}

MemoryCacheSettings MemoryCacheSettings::WithMemoryGarbageCollectorSettings(
    const MemoryGarbageCollectorSettings& settings) {
  MemoryCacheSettings new_settings(*this);
  new_settings.settings_ = CopyMemoryGcSettings(settings);
  return new_settings;
}

size_t Settings::Hash() const {
  return util::Hash(host_, ssl_enabled_, persistence_enabled_,
                    cache_size_bytes_, cache_settings_);
}

bool operator==(const Settings& lhs, const Settings& rhs) {
  bool eq = lhs.host_ == rhs.host_ && lhs.ssl_enabled_ == rhs.ssl_enabled_ &&
            lhs.persistence_enabled_ == rhs.persistence_enabled_ &&
            lhs.cache_size_bytes_ == rhs.cache_size_bytes_;
  if (!eq) {
    return eq;
  }

  if (lhs.cache_settings_ == nullptr && rhs.cache_settings_ == nullptr) {
    return eq;
  }

  if (lhs.cache_settings_ == nullptr || rhs.cache_settings_ == nullptr) {
    return false;
  }
  return *(lhs.cache_settings_) == *(rhs.cache_settings_);
}

bool operator!=(const Settings& lhs, const Settings& rhs) {
  return !(lhs == rhs);
}

bool operator==(const LocalCacheSettings& lhs, const LocalCacheSettings& rhs) {
  if (lhs.kind() != rhs.kind()) {
    return false;
  }

  if (lhs.kind() == LocalCacheSettings::Kind::kMemory) {
    return static_cast<const MemoryCacheSettings&>(lhs) ==
           static_cast<const MemoryCacheSettings&>(rhs);
  }

  if (lhs.kind() == LocalCacheSettings::Kind::kPersistent) {
    return static_cast<const PersistentCacheSettings&>(lhs) ==
           static_cast<const PersistentCacheSettings&>(rhs);
  }
  UNREACHABLE();
}

bool operator==(const MemoryGarbageCollectorSettings& lhs,
                const MemoryGarbageCollectorSettings& rhs) {
  if (lhs.kind() != rhs.kind()) {
    return false;
  }

  if (lhs.kind() == MemoryGarbageCollectorSettings::MemoryGcKind::kEagerGc) {
    return static_cast<const MemoryEagerGcSettings&>(lhs) ==
           static_cast<const MemoryEagerGcSettings&>(rhs);
  }

  if (lhs.kind() == MemoryGarbageCollectorSettings::MemoryGcKind::kLruGc) {
    return static_cast<const MemoryLruGcSettings&>(lhs) ==
           static_cast<const MemoryLruGcSettings&>(rhs);
  }
  UNREACHABLE();
}

bool operator!=(const LocalCacheSettings& lhs, const LocalCacheSettings& rhs) {
  return !(lhs == rhs);
}

size_t MemoryCacheSettings::Hash() const {
  return util::Hash(kind_, *settings_);
}

size_t PersistentCacheSettings::Hash() const {
  return util::Hash(kind_, size_bytes_);
}

size_t MemoryEagerGcSettings::Hash() const {
  return util::Hash(kind_);
}

size_t MemoryLruGcSettings::Hash() const {
  return util::Hash(kind_, size_bytes_);
}

bool operator==(const MemoryCacheSettings& lhs,
                const MemoryCacheSettings& rhs) {
  return lhs.kind() == rhs.kind() && lhs.gc_settings() == rhs.gc_settings();
}

bool operator!=(const MemoryCacheSettings& lhs,
                const MemoryCacheSettings& rhs) {
  return !(lhs == rhs);
}

bool operator==(const PersistentCacheSettings& lhs,
                const PersistentCacheSettings& rhs) {
  return lhs.kind() == rhs.kind() && lhs.size_bytes() == rhs.size_bytes();
}

bool operator!=(const PersistentCacheSettings& lhs,
                const PersistentCacheSettings& rhs) {
  return !(lhs == rhs);
}

bool operator==(const MemoryEagerGcSettings& lhs,
                const MemoryEagerGcSettings& rhs) {
  return lhs.kind() == rhs.kind();
}

bool operator!=(const MemoryEagerGcSettings& lhs,
                const MemoryEagerGcSettings& rhs) {
  return !(lhs == rhs);
}

bool operator==(const MemoryLruGcSettings& lhs,
                const MemoryLruGcSettings& rhs) {
  return lhs.kind() == rhs.kind() && lhs.size_bytes() == rhs.size_bytes();
}

bool operator!=(const MemoryLruGcSettings& lhs,
                const MemoryLruGcSettings& rhs) {
  return !(lhs == rhs);
}

void Settings::set_persistence_enabled(bool value) {
  HARD_ASSERT(cache_settings_ == nullptr,
              "Cannot change persistence when "
              "local cache settings is already specified. Instead, specify "
              "persistence as part of local cache settings.");
  persistence_enabled_ = value;
}

bool Settings::persistence_enabled() const {
  if (cache_settings_) {
    return cache_settings_->kind() == LocalCacheSettings::Kind::kPersistent;
  }

  return persistence_enabled_;
}

void Settings::set_cache_size_bytes(int64_t value) {
  HARD_ASSERT(cache_settings_ == nullptr,
              "Cannot change cache size when "
              "local cache settings is already specified. Instead, specify "
              "cache size as part of local cache settings.");
  cache_size_bytes_ = value;
}

int64_t Settings::cache_size_bytes() const {
  if (cache_settings_) {
    if (cache_settings_->kind() == api::LocalCacheSettings::Kind::kPersistent) {
      return static_cast<const PersistentCacheSettings*>(cache_settings_.get())
          ->size_bytes_;
    } else {
      auto* memory_cache_settings =
          static_cast<MemoryCacheSettings*>(cache_settings_.get());
      if (memory_cache_settings->gc_settings().kind() ==
          MemoryGarbageCollectorSettings::MemoryGcKind::kLruGc) {
        return static_cast<const MemoryLruGcSettings&>(
                   memory_cache_settings->gc_settings())
            .size_bytes();
      } else {
        return CacheSizeUnlimited;
      }
    }
  }
  return cache_size_bytes_;
}

bool Settings::gc_enabled() const {
  if (cache_settings_) {
    if (cache_settings_->kind_ == LocalCacheSettings::Kind::kPersistent) {
      return static_cast<PersistentCacheSettings*>(cache_settings_.get())
                 ->size_bytes_ != CacheSizeUnlimited;
    } else {
      auto* memory_cache_settings =
          static_cast<MemoryCacheSettings*>(cache_settings_.get());
      return memory_cache_settings->gc_settings().kind() ==
                 MemoryGarbageCollectorSettings::MemoryGcKind::kLruGc &&
             static_cast<const MemoryLruGcSettings&>(
                 memory_cache_settings->gc_settings())
                     .size_bytes() != CacheSizeUnlimited;
    }
  }

  return persistence_enabled_ && cache_size_bytes_ != CacheSizeUnlimited;
}

const LocalCacheSettings* Settings::local_cache_settings() const {
  return cache_settings_.get();
}

void Settings::set_local_cache_settings(const LocalCacheSettings& settings) {
  HARD_ASSERT(persistence_enabled_ == Settings::DefaultPersistenceEnabled,
              "Cannot set local cache settings, because persistence_enabled "
              "is already specified. Please remove code specifying "
              "persistence_enabled.");
  HARD_ASSERT(
      cache_size_bytes_ == Settings::DefaultCacheSizeBytes,
      "Cannot set local cache settings, because cache_size_bytes "
      "is already specified. Please remove code specifying cache_size_bytes.");
  cache_settings_ = CopyCacheSettings(settings);
}

PersistentCacheSettings PersistentCacheSettings::WithSizeBytes(
    int64_t size) const {
  PersistentCacheSettings new_settings{*this};
  new_settings.size_bytes_ = size;
  return new_settings;
}

}  // namespace api
}  // namespace firestore
}  // namespace firebase
