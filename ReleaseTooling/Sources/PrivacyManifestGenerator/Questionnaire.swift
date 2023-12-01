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

enum QuestionnaireError: Error {
  case invalidAnswer
  case endOfQuestionnaireSection
  case missingExpectedAnswer(message: String)
}

/// A structure representing a series of questions.
struct Questionnaire {
  /// Types of answers that a given question accepts.
  enum Answer {
    /// A "yes" or "no" answer. The question, _do you like cookies?_ should have  a `.bool(_)`
    /// answer.
    case bool(Bool)
    /// A non-bool answer. The question, _what is your name?_ should have a `.string(_)` answer.
    case string(String)
  }

  /// A structure representing a question within a questionnaire.
  struct Question {
    /// The question's string query, for example, _What is your name?_.
    let question: String
    /// Whether or not the question can be skipped.
    let isSkippable: Bool
    /// A closure to be invoked with the answer to the question.
    let answerHandler: (Answer) throws -> Void

    init(question: String,
         isSkippable: Bool = false,
         answerHandler: @escaping (Answer) throws -> Void) {
      self.question = question
      self.isSkippable = isSkippable
      self.answerHandler = answerHandler
    }
  }

  /// A structure representing a series of related questions.
  struct Section {
    private var questionIterator: IndexingIterator<[Question]>

    init(questions: [Question]) {
      questionIterator = questions.makeIterator()
    }

    mutating func nextQuestion() -> Question? {
      questionIterator.next()
    }
  }

  private var sectionsIterator: IndexingIterator<[Section]>
  private var currentSection: Section?
  private var currentQuestion: Question?

  init(sections: [Section]) {
    sectionsIterator = sections.makeIterator()
    currentSection = sectionsIterator.next()
  }

  /// Moves to and returns the next question in the questionnaire.
  /// - Returns: The next question in the questionnaire, if any.
  mutating func nextQuestion() -> Question? {
    if currentSection == nil {
      return nil
    }

    guard let nextQuestion = currentSection!.nextQuestion() else {
      currentSection = sectionsIterator.next()
      return nextQuestion()
    }

    currentQuestion = nextQuestion

    return nextQuestion
  }

  /// Calls the current question's answer handling closure with the given answer.
  /// - Parameter answer: The answer to pass to the current question's answer handling closure.
  mutating func processAnswer(_ answer: Answer) throws {
    if
      currentQuestion?.isSkippable == true,
      case let .string(string) = answer,
      string == "skip"
    { return }

    do {
      try currentQuestion?.answerHandler(answer)
    } catch QuestionnaireError.endOfQuestionnaireSection {
      // Ignore and move on to next question.
      currentSection = sectionsIterator.next()
    } catch {
      throw error
    }
  }
}
