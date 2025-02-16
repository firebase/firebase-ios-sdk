// Copyright 2025 Google LLC
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

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
public class MultimodalLiveModel: NSObject {
  let host = "daily-firebaseml.sandbox.googleapis.com"
  let modelName: String
  let projectID: String
  let modelURI: String
  let urlRequest: URLRequest
  let decoder = JSONDecoder()
  let encoder = JSONEncoder()
  lazy var urlSession = URLSession(
    configuration: URLSessionConfiguration.default,
    delegate: self,
    delegateQueue: nil
  )
  lazy var webSocketTask: URLSessionWebSocketTask = urlSession.webSocketTask(with: urlRequest)

  public init(modelName: String, projectID: String, apiKey: String, location: String) {
    self.modelName = modelName
    self.projectID = projectID
    let urlString =
      "wss://\(host)/ws/google.firebase.machinelearning.v2beta.LlmBidiService/BidiGenerateContent"
    guard let url = URL(string: urlString) else {
      fatalError("\(urlString) is not a valid URL.")
    }
    var urlRequest = URLRequest(url: url)
    urlRequest.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    self.urlRequest = urlRequest

    modelURI =
      "projects/\(projectID)/locations/\(location)/publishers/google/models/\(modelName)"
  }

  deinit {
    disconnect()
  }

  public func connect() async {
    webSocketTask.resume()
  }

  public func disconnect() {
    print("Disconnecting...")
    webSocketTask.cancel(with: .goingAway, reason: nil)
    urlSession.finishTasksAndInvalidate()
    print("Disconnected.")
  }

  func sendInitialSetupMessages() async -> Bool {
    let setup = BidiGenerateContentClientMessage.setup(
      BidiGenerateContentSetup(
        model: modelURI,
        generationConfig: GenerationConfig(responseModalities: ["TEXT"])
      )
    )
    let setupData: Data?
    do {
      setupData = try JSONEncoder().encode(setup)
    } catch {
      print("Error encoding BidiGenerateContentSetup.")
      setupData = nil
    }
    guard let setupData else {
      disconnect()
      return false
    }
    guard let setupDataJSON = String(data: setupData, encoding: .utf8) else {
      disconnect()
      return false
    }
    do {
      print("Sending BidiGenerateContentSetup...")
      try await webSocketTask.send(.data(setupData))
      print("Sent BidiGenerateContentSetup.")
      print("BidiGenerateContentSetup JSON: \(setupDataJSON)")
    } catch {
      print("Error sending BidiGenerateContentSetup.")
      disconnect()
      return false
    }

    let setupResponse: URLSessionWebSocketTask.Message?
    do {
      print("Receiving BidiGenerateContentServerMessage...")
      setupResponse = try await webSocketTask.receive()
      print("Received BidiGenerateContentServerMessage.")
    } catch {
      print("Error receiving BidiGenerateContentSetupComplete response: \(error)")
      setupResponse = nil
    }

    guard let setupResponse else {
      disconnect()
      return false
    }
    guard case let .data(data) = setupResponse else {
      print("Received unknown response type: \(setupResponse)")
      disconnect()
      return false
    }
    guard let serverMessageJSON = String(data: data, encoding: .utf8) else {
      disconnect()
      return false
    }
    print("BidiGenerateContentServerMessage JSON: \(serverMessageJSON)")

    let serverMessage: BidiGenerateContentServerMessage?
    do {
      serverMessage = try decoder.decode(BidiGenerateContentServerMessage.self, from: data)
    } catch {
      print("Failed to decode BidiGenerateContentServerMessage: \(error)")
      serverMessage = nil
    }
    guard let serverMessage else {
      disconnect()
      return false
    }
    guard case .setupComplete = serverMessage else {
      print("Received unknown server message: \(serverMessage)")
      disconnect()
      return false
    }
    print("Processed BidiGenerateContentSetupComplete message.")
    return true
  }

  func startListening() async {
    guard case .running = webSocketTask.state else {
      print("The WebSocket is in an unexpected state: \(webSocketTask.state).")
      return
    }

    while webSocketTask.state == .running {
      let message: URLSessionWebSocketTask.Message?
      do {
        print("Waiting for a BidiGenerateContentServerMessage...")
        message = try await webSocketTask.receive()
        print("Received BidiGenerateContentServerMessage.")
      } catch {
        print("Error receiving BidiGenerateContentServerMessage: \(error)")
        message = nil
      }

      guard let message else {
        disconnect()
        return
      }
      guard case let .data(data) = message else {
        print("Received unexpected message type: \(message)")
        disconnect()
        return
      }
      guard let messageJSON = String(data: data, encoding: .utf8) else {
        print("Failed to decode BidiGenerateContentServerMessage as JSON.")
        disconnect()
        return
      }

      let serverMessage: BidiGenerateContentServerMessage?
      do {
        serverMessage = try decoder.decode(BidiGenerateContentServerMessage.self, from: data)
      } catch {
        print("Failed to decode BidiGenerateContentServerMessage: \(error)")
        print("BidiGenerateContentServerMessage JSON: \(messageJSON)")
        serverMessage = nil
      }
      guard let serverMessage else {
        disconnect()
        return
      }
      print("Decoded BidiGenerateContentServerMessage: \(serverMessage)")
      print("BidiGenerateContentServerMessage JSON: \(messageJSON)")
    }
  }

  public func sendAudioMessage(audioData: Data) async {
    let audioPart = InlineData(data: audioData, mimeType: "audio/pcm")
    let realtimeInput = BidiGenerateContentRealtimeInput(mediaChunks: [audioPart])
    let clientMessage = BidiGenerateContentClientMessage.realtimeInput(realtimeInput)

    let messageData: Data?
    do {
      messageData = try JSONEncoder().encode(clientMessage)
    } catch {
      print("Error encoding BidiGenerateContentClientMessage.")
      messageData = nil
    }
    guard let messageData else {
      disconnect()
      return
    }
    guard let messageJSON = String(data: messageData, encoding: .utf8) else {
      print("Failed to convert BidiGenerateContentClientMessage to JSON.")
      disconnect()
      return
    }
    do {
      print("Sending BidiGenerateContentClientMessage JSON: \(messageJSON)")
      try await webSocketTask.send(.data(messageData))
      print("Sent BidiGenerateContentClientMessage.")
    } catch {
      print("Error sending BidiGenerateContentClientMessage.")
      disconnect()
      return
    }

    print("Start listening for a response...")
    await startListening()
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
extension MultimodalLiveModel: URLSessionWebSocketDelegate {
  public func urlSession(_ session: URLSession,
                         webSocketTask: URLSessionWebSocketTask,
                         didOpenWithProtocol protocol: String?) {
    print("WebSocket opened.")
    Task {
      print("Sending initial setup messages after WebSocket opened.")
      if await sendInitialSetupMessages() == false {
        print("Setup failed.")
      }
    }
  }

  public func urlSession(_ session: URLSession,
                         webSocketTask: URLSessionWebSocketTask,
                         didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
                         reason: Data?) {
    print("WebSocket closed with code: \(closeCode)")
  }
}
