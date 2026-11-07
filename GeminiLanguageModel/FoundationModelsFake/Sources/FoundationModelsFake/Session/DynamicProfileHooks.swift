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
  #if canImport(FoundationEssentials)
    import FoundationEssentials
  #else
    import Foundation
  #endif

  // MARK: - Internal Hook Modifier Primitives

  /// Internal profile wrapper that registers a turn or lifecycle hook on the underlying profile.
  internal struct _HookDynamicProfile<Base: LanguageModelSession.DynamicProfile>:
    LanguageModelSession.DynamicProfile, _DynamicProfilePrimitive
  {
    /// The kind of lifecycle or turn hook carried by this wrapper.
    internal enum HookKind: Sendable {
      case onPrompt(@Sendable (Transcript.Prompt) async throws -> Void)
      case onResponse(@Sendable (Transcript.Response) async throws -> Void)
      case onReasoning(@Sendable (Transcript.Reasoning) async throws -> Void)
      case onToolCall(@Sendable (Transcript.ToolCall) async throws -> Void)
      case onToolOutput(@Sendable (Transcript.ToolCall, Transcript.ToolOutput) async throws -> Void)
      case onActivate(@Sendable () async -> Void)
      case onDeactivate(@Sendable () async -> Void)
    }

    /// The type of dynamic profile representing the body of this profile.
    internal typealias Body = Never

    /// The underlying profile node.
    internal let base: Base

    /// The hook payload to register.
    internal let kind: HookKind

    /// The content and behavior of the dynamic profile.
    internal var body: Never {
      fatalError("_HookDynamicProfile.body should not be called.")
    }

    /// Evaluates `kind` and `base`, collecting `onActivate` outer-to-inner and all other hooks
    /// inner-to-outer.
    internal func _evaluate(into context: inout ProfileEvaluationContext) {
      if case .onActivate(let action) = kind {
        context.onActivateHooks.append(
          ProfileLifecycleHook(path: context.currentPath, action: action)
        )
      }

      DynamicProfileEvaluator.evaluateNode(base, into: &context)

      switch kind {
      case .onPrompt(let action):
        context.onPromptHooks.append(action)
      case .onResponse(let action):
        context.onResponseHooks.append(action)
      case .onReasoning(let action):
        context.onReasoningHooks.append(action)
      case .onToolCall(let action):
        context.onToolCallHooks.append(action)
      case .onToolOutput(let action):
        context.onToolOutputHooks.append(action)
      case .onActivate:
        break
      case .onDeactivate(let action):
        context.onDeactivateHooks.append(
          ProfileLifecycleHook(path: context.currentPath, action: action)
        )
      }
    }
  }

  // MARK: - Public Lifecycle Hook Methods

  extension LanguageModelSession.DynamicProfile {
    /// Registers an asynchronous action to run when a prompt is appended to the transcript.
    ///
    /// - Parameter action: The asynchronous closure to execute.
    /// - Returns: A dynamic profile configured with the prompt hook.
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public func onPrompt(
      @_inheritActorContext perform action: sending @escaping () async throws -> Void
    ) -> some LanguageModelSession.DynamicProfile {
      nonisolated(unsafe) let transferredAction = action
      return _HookDynamicProfile(
        base: self,
        kind: .onPrompt { _ in
          try await unsafe transferredAction()
        }
      )
    }

    /// Registers an asynchronous action to run with the prompt when a prompt is appended.
    ///
    /// - Parameter action: The asynchronous closure to execute with the prompt.
    /// - Returns: A dynamic profile configured with the prompt hook.
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public func onPrompt(
      @_inheritActorContext perform action:
        sending @escaping (Transcript.Prompt) async throws -> Void
    ) -> some LanguageModelSession.DynamicProfile {
      nonisolated(unsafe) let transferredAction = action
      return _HookDynamicProfile(
        base: self,
        kind: .onPrompt { prompt in
          try await unsafe transferredAction(prompt)
        }
      )
    }

    /// Registers an asynchronous action to run when a model response is completed.
    ///
    /// - Parameter action: The asynchronous closure to execute.
    /// - Returns: A dynamic profile configured with the response hook.
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public func onResponse(
      @_inheritActorContext perform action: sending @escaping () async throws -> Void
    ) -> some LanguageModelSession.DynamicProfile {
      nonisolated(unsafe) let transferredAction = action
      return _HookDynamicProfile(
        base: self,
        kind: .onResponse { _ in
          try await unsafe transferredAction()
        }
      )
    }

    /// Registers an asynchronous action to run with the response when generation finishes.
    ///
    /// - Parameter action: The asynchronous closure to execute with the response.
    /// - Returns: A dynamic profile configured with the response hook.
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public func onResponse(
      @_inheritActorContext perform action:
        sending @escaping (Transcript.Response) async throws -> Void
    ) -> some LanguageModelSession.DynamicProfile {
      nonisolated(unsafe) let transferredAction = action
      return _HookDynamicProfile(
        base: self,
        kind: .onResponse { response in
          try await unsafe transferredAction(response)
        }
      )
    }

    /// Registers an asynchronous action to run when model reasoning is finalized.
    ///
    /// - Parameter action: The asynchronous closure to execute.
    /// - Returns: A dynamic profile configured with the reasoning hook.
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public func onReasoning(
      @_inheritActorContext perform action: sending @escaping () async throws -> Void
    ) -> some LanguageModelSession.DynamicProfile {
      nonisolated(unsafe) let transferredAction = action
      return _HookDynamicProfile(
        base: self,
        kind: .onReasoning { _ in
          try await unsafe transferredAction()
        }
      )
    }

    /// Registers an asynchronous action to run with reasoning details when reasoning is finalized.
    ///
    /// - Parameter action: The asynchronous closure to execute with the reasoning entry.
    /// - Returns: A dynamic profile configured with the reasoning hook.
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public func onReasoning(
      @_inheritActorContext perform action:
        sending @escaping (Transcript.Reasoning) async throws -> Void
    ) -> some LanguageModelSession.DynamicProfile {
      nonisolated(unsafe) let transferredAction = action
      return _HookDynamicProfile(
        base: self,
        kind: .onReasoning { reasoning in
          try await unsafe transferredAction(reasoning)
        }
      )
    }

    /// Registers an asynchronous action to run before a tool call executes.
    ///
    /// - Parameter action: The asynchronous closure to execute.
    /// - Returns: A dynamic profile configured with the tool-call hook.
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public func onToolCall(
      @_inheritActorContext perform action: sending @escaping () async throws -> Void
    ) -> some LanguageModelSession.DynamicProfile {
      nonisolated(unsafe) let transferredAction = action
      return _HookDynamicProfile(
        base: self,
        kind: .onToolCall { _ in
          try await unsafe transferredAction()
        }
      )
    }

    /// Registers an asynchronous action to run with tool call information before execution.
    ///
    /// - Parameter action: The asynchronous closure to execute with the tool call.
    /// - Returns: A dynamic profile configured with the tool-call hook.
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public func onToolCall(
      @_inheritActorContext perform action:
        sending @escaping (Transcript.ToolCall) async throws -> Void
    ) -> some LanguageModelSession.DynamicProfile {
      nonisolated(unsafe) let transferredAction = action
      return _HookDynamicProfile(
        base: self,
        kind: .onToolCall { call in
          try await unsafe transferredAction(call)
        }
      )
    }

    /// Registers an asynchronous action to run after a tool call produces an output.
    ///
    /// - Parameter action: The asynchronous closure to execute.
    /// - Returns: A dynamic profile configured with the tool-output hook.
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public func onToolOutput(
      @_inheritActorContext perform action: sending @escaping () async throws -> Void
    ) -> some LanguageModelSession.DynamicProfile {
      nonisolated(unsafe) let transferredAction = action
      return _HookDynamicProfile(
        base: self,
        kind: .onToolOutput { _, _ in
          try await unsafe transferredAction()
        }
      )
    }

    /// Registers an asynchronous action to run with the tool call and output after execution.
    ///
    /// - Parameter action: The asynchronous closure to execute with the tool call and output.
    /// - Returns: A dynamic profile configured with the tool-output hook.
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public func onToolOutput(
      @_inheritActorContext perform action:
        sending @escaping (
          Transcript.ToolCall,
          Transcript.ToolOutput
        ) async throws -> Void
    ) -> some LanguageModelSession.DynamicProfile {
      nonisolated(unsafe) let transferredAction = action
      return _HookDynamicProfile(
        base: self,
        kind: .onToolOutput { call, output in
          try await unsafe transferredAction(call, output)
        }
      )
    }

    /// Registers an asynchronous action to run when this profile branch becomes active.
    ///
    /// - Parameter action: The asynchronous closure to execute on profile activation.
    /// - Returns: A dynamic profile configured with the activation hook.
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public func onActivate(
      @_inheritActorContext perform action: sending @escaping @isolated(any) () async -> Void
    ) -> some LanguageModelSession.DynamicProfile {
      nonisolated(unsafe) let transferredAction = action
      return _HookDynamicProfile(
        base: self,
        kind: .onActivate {
          await unsafe transferredAction()
        }
      )
    }

    /// Registers an asynchronous action to run when this profile branch is deactivated.
    ///
    /// - Parameter action: The asynchronous closure to execute on profile deactivation.
    /// - Returns: A dynamic profile configured with the deactivation hook.
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public func onDeactivate(
      @_inheritActorContext perform action: sending @escaping @isolated(any) () async -> Void
    ) -> some LanguageModelSession.DynamicProfile {
      nonisolated(unsafe) let transferredAction = action
      return _HookDynamicProfile(
        base: self,
        kind: .onDeactivate {
          await unsafe transferredAction()
        }
      )
    }
  }
#endif  // compiler(>=6.4)
