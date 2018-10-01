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

#ifndef FIRESTORE_CORE_INCLUDE_FIREBASE_FIRESTORE_SETTINGS_H_
#define FIRESTORE_CORE_INCLUDE_FIREBASE_FIRESTORE_SETTINGS_H_

#include <string>

namespace firebase {
namespace firestore {

/** Settings used to configure a Firestore instance. */
class Settings {
 public:
  Settings();

  /**
   * Gets the host of the Firestore backend to connect to.
   */
  const std::string& host() const {
    return host_;
  }

  /**
   * Returns whether to use SSL when communicating.
   */
  bool ssl_enabled() const {
    return ssl_enabled_;
  }

  /**
   * Returns whether to enable local persistent storage.
   */
  bool persistence_enabled() const {
    return persistence_enabled_;
  }

  /**
   * Sets the host of the Firestore backend e.g. "firestore.googleapis.com".
   *
   * @param host The host string.
   */
  void set_host(std::string host);

  /**
   * Enables or disables SSL for communication.
   *
   * @param enabled Set true to enable SSL for communication.
   */
  void set_ssl_enabled(bool enabled);

  /**
   * Enables or disables local persistent storage.
   *
   * @param enabled Set true to enable local persistent storage.
   */
  void set_persistence_enabled(bool enabled);

 private:
  std::string host_;
  bool ssl_enabled_;
  bool persistence_enabled_;
};

}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_INCLUDE_FIREBASE_FIRESTORE_SETTINGS_H_
