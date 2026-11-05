// Copyright 2026 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#if compiler(>=6.4)
  import Synchronization

  extension LanguageModelSession {
    /// The dynamic property values associated with this session.
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public final var properties: SessionPropertyValues {
      state.withLock { state in
        if let existing = state._propertyValuesBox as? SessionPropertyValues {
          return existing
        }
        let created = SessionPropertyValues(session: self)
        state._propertyValuesBox = created
        return created
      }
    }
  }
#endif  // compiler(>=6.4)
