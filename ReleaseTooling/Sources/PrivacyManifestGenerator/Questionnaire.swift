// Copyright 2023 Google LLC
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

import Foundation

/// A structure representing a series of questions.
struct Questionnaire {
  /// A structure representing a question within a questionnaire.
  struct Question {
    /// The question's string query, for example, _What is your name?_.
    let question: String
    /// A closure to be invoked with the answer to the question.
    let answerHandler: (_ answer: Any) throws -> Void
  }

  /// Moves to and returns the next question in the questionnaire.
  /// - Returns: The next question in the questionnaire, if any.
  mutating func nextQuestion() -> Question? {
    // TODO(ncooke3): Implement.
    nil
  }

  /// Calls the current question's answer handling closure with the given answer.
  /// - Parameter answer: The answer to pass to the current question's answer handling closure.
  func processAnswer(_ answer: String) throws {
    // TODO(ncooke3): Implement.
  }
}
