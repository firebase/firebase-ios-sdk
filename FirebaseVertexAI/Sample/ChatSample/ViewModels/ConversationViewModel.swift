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

import FirebaseVertexAI
import Foundation
import UIKit

@MainActor
class ConversationViewModel: ObservableObject {
  /// This array holds both the user's and the system's chat messages
  @Published var messages = [ChatMessage]()

  /// Indicates we're waiting for the model to finish or the UI is loading
  @Published var busy = true

  @Published var error: Error?
  var hasError: Bool {
    return error != nil
  }

  private var model: GenerativeModel
  private var chat: Chat? = nil
  private var stopGenerating = false

  private var chatTask: Task<Void, Never>?

  init() {
    model = VertexAI.vertexAI().generativeModel(modelName: "gemini-1.5-flash")
    Task {
      await startNewChat()
    }
  }

  func sendMessage(_ text: String, streaming: Bool = true) async {
    stop()
    if streaming {
      await internalSendMessageStreaming(text)
    } else {
      await internalSendMessage(text)
    }
  }

  func startNewChat() async {
    busy = true
    defer {
      busy = false
    }
    stop()
    messages.removeAll()
    chat = await model.startChat()
  }

  func stop() {
    chatTask?.cancel()
    error = nil
  }

  private func internalSendMessageStreaming(_ text: String) async {
    chatTask = Task {
      busy = true
      defer {
        busy = false
      }

      // first, add the user's message to the chat
      let userMessage = ChatMessage(message: text, participant: .user)
      messages.append(userMessage)

      // add a pending message while we're waiting for a response from the backend
      let systemMessage = ChatMessage.pending(participant: .system)
      messages.append(systemMessage)

      do {
        guard let chat else {
          throw ChatError.notInitialized
        }
        let responseStream = try await chat.sendMessageStream(text)
        for try await chunk in responseStream {
          messages[messages.count - 1].pending = false
          if let text = chunk.text {
            messages[messages.count - 1].message += text
          }
        }
      } catch {
        self.error = error
        print(error.localizedDescription)
        messages.removeLast()
      }
    }
  }

  private func internalSendMessage(_ text: String) async {
    chatTask = Task {
      busy = true
      defer {
        busy = false
      }

      // first, add the user's message to the chat
      let userMessage = ChatMessage(message: text, participant: .user)
      messages.append(userMessage)

      // add a pending message while we're waiting for a response from the backend
      let systemMessage = ChatMessage.pending(participant: .system)
      messages.append(systemMessage)

      do {
        guard let chat = chat else {
          throw ChatError.notInitialized
        }
        let response = try await chat.sendMessage(text)

        if let responseText = response.text {
          // replace pending message with backend response
          messages[messages.count - 1].message = responseText
          messages[messages.count - 1].pending = false
        }
      } catch {
        self.error = error
        print(error.localizedDescription)
        messages.removeLast()
      }
    }
  }

  enum ChatError: Error {
    case notInitialized
  }
}
