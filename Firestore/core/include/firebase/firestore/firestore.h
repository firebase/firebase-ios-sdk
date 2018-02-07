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

// TODO(rsgowman): This file isn't intended to be used just yet. It's just an
// outline of what the API might eventually look like. Most of this was
// shamelessly stolen and modified from rtdb's header file, melded with the
// firestore api.

#ifndef FIRESTORE_CORE_INCLUDE_FIREBASE_FIRESTORE_FIRESTORE_H_
#define FIRESTORE_CORE_INCLUDE_FIREBASE_FIRESTORE_FIRESTORE_H_

#include <string>

// TODO(rsgowman): replace these forward decl's with appropriate includes (once
// they exist)
namespace firebase {
class App;
class InitResult;
}  // namespace firebase

namespace firebase {
namespace firestore {

// TODO(rsgowman): replace these forward decl's with appropriate includes (once
// they exist)
class DocumentReference;
class CollectionReference;
class Settings;

/**
 * @brief Entry point for the Firebase Firestore C++ SDK.
 *
 * To use the SDK, call firebase::firestore::Firestore::GetInstance() to obtain
 * an instance of Firestore, then use Collection() or Document() to obtain
 * references to child paths within the database. From there you can set data
 * via CollectionReference::Add() and DocumentReference::Set(), or get data via
 * CollectionReference::Get() and DocumentReference::Get(), attach listeners,
 * and more.
 *
 * Subclassing Note: Firestore classes are not meant to be subclassed except for
 * use in test mocks. Subclassing is not supported in production code and new
 * SDK releases may break code that does so.
 */
class Firestore {
 public:
  /**
   * @brief Returns an instance of Firestore corresponding to the given App.
   *
   * Firebase Firestore uses firebase::App to communicate with Firebase
   * Authentication to authenticate users to the Firestore server backend.
   *
   * If you call GetInstance() multiple times with the same App, you will get
   * the same instance of App.
   *
   * @param[in] app Your instance of firebase::App. Firebase Firestore will use
   * this to communicate with Firebase Authentication.
   * @param[out] init_result_out Optional: If provided, write the init result
   * here. Will be set to kInitResultSuccess if initialization succeeded, or
   * kInitResultFailedMissingDependency on Android if Google Play services is
   * not available on the current device.
   *
   * @returns An instance of Firestore corresponding to the given App.
   */
  static Firestore* GetInstance(::firebase::App* app,
                                InitResult* init_result_out = nullptr);

  static Firestore* GetInstance(InitResult* init_result_out = nullptr);

  /**
   * @brief Destructor for the Firestore object.
   *
   * When deleted, this instance will be removed from the cache of Firestore
   * objects. If you call GetInstance() in the future with the same App, a new
   * Firestore instance will be created.
   */
  virtual ~Firestore();

  /**
   * @brief Returns the firebase::App that this Firestore was created with.
   *
   * @returns The firebase::App this Firestore was created with.
   */
  virtual const App* app() const;

  /**
   * @brief Returns the firebase::App that this Firestore was created with.
   *
   * @returns The firebase::App this Firestore was created with.
   */
  virtual App* app();

  /**
   * @brief Returns a CollectionReference instance that refers to the
   * collection at the specified path within the database.
   *
   * @param[in] collection_path A slash-separated path to a collection.
   *
   * @return The CollectionReference instance.
   */
  virtual CollectionReference Collection(const char* collection_path) const;

  /**
   * @brief Returns a CollectionReference instance that refers to the
   * collection at the specified path within the database.
   *
   * @param[in] collection_path A slash-separated path to a collection.
   *
   * @return The CollectionReference instance.
   */
  virtual CollectionReference Collection(
      const std::string& collection_path) const;

  /**
   * @brief Returns a DocumentReference instance that refers to the document at
   * the specified path within the database.
   *
   * @param[in] document_path A slash-separated path to a document.
   * @return The DocumentReference instance.
   */
  virtual DocumentReference Document(const char* document_path) const;

  /**
   * @brief Returns a DocumentReference instance that refers to the document at
   * the specified path within the database.
   *
   * @param[in] document_path A slash-separated path to a document.
   *
   * @return The DocumentReference instance.
   */
  virtual DocumentReference Document(const std::string& document_path) const;

  /** Returns the settings used by this Firestore object. */
  virtual Settings settings() const;

  /** Sets any custom settings used to configure this Firestore object. */
  virtual void set_settings(const Settings& settings);

  // TODO(rsgowman): batch(), runTransaction()

  /** Globally enables / disables Firestore logging for the SDK. */
  static void set_logging_enabled(bool logging_enabled);
};

}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_INCLUDE_FIREBASE_FIRESTORE_FIRESTORE_H_
