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
  public import Observation
  import Synchronization

  #if canImport(FoundationEssentials)
    import FoundationEssentials
  #else
    import Foundation
  #endif

  // MARK: - SessionPropertyKey & Macros

  /// A key type used to identify and store custom values in session property storage.
  ///
  /// > Important: Part of a fake of Apple's Foundation Models framework, for development and testing
  /// > only. For the production API, see
  /// > [`SessionPropertyKey`](https://developer.apple.com/documentation/foundationmodels/sessionpropertykey).
  @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  public protocol SessionPropertyKey: SendableMetatype {
    /// The type of value identified by this key.
    associatedtype Value: Sendable

    /// The default value used when no explicit value is set for this key.
    static var defaultValue: Self.Value { get }
  }

  /// A macro that declares a custom session property entry on ``SessionPropertyValues``.
  ///
  /// > Important: Part of a fake of Apple's Foundation Models framework, for development and testing
  /// > only. For the production API, see
  /// > [`SessionPropertyEntry`](https://developer.apple.com/documentation/foundationmodels/sessionpropertyentry()).
  @attached(accessor)
  @attached(peer, names: prefixed(__Key_))
  @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  public macro SessionPropertyEntry() =
    #externalMacro(
      module: "FoundationModelsFakeMacros",
      type: "SessionPropertyEntryMacro"
    )

  /// A macro used internally to synthesize accessor logic for session property default values.
  @attached(accessor)
  public macro __SessionPropertyEntryDefaultValue() =
    #externalMacro(
      module: "FoundationModelsFakeMacros",
      type: "SessionPropertyEntryDefaultValueMacro"
    )

  // MARK: - SessionPropertyValues

  /// A storage container for custom and system properties associated with a session.
  ///
  /// > Important: Part of a fake of Apple's Foundation Models framework, for development and testing
  /// > only. For the production API, see
  /// > [`SessionPropertyValues`](https://developer.apple.com/documentation/foundationmodels/sessionpropertyvalues).
  @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  public final class SessionPropertyValues: Sendable {
    /// Whether the current task is executing inside `Tool.call(arguments:)`.
    ///
    /// Writing `@SessionProperty(\.history)` inside `Tool.call(arguments:)` is a silent no-op.
    @TaskLocal internal static var isExecutingToolCall: Bool = false

    /// Whether the current task is running a profile hook, where `history` writes are part of the
    /// session's own call rather than outside mutations.
    ///
    /// Like any task-local value, it's inherited by tasks that a hook starts.
    @TaskLocal internal static var isInHistoryWriteScope: Bool = false

    /// Mutable storage state synchronized by `state`.
    private struct State: Sendable {
      /// Weak reference to the owning session, avoiding reference cycles.
      weak var session: LanguageModelSession?

      /// Custom property values keyed by the `ObjectIdentifier` of the `SessionPropertyKey` metatype.
      var storage: [ObjectIdentifier: any Sendable] = [:]
    }

    /// Mutex guarding the property dictionary and weak session reference.
    private let state: Mutex<State>

    /// The registrar that notifies observers of custom properties and `history`.
    ///
    /// Like `LanguageModelSession`, `access` and `withMutation` are always invoked outside any
    /// `Mutex` lock so observer callbacks never deadlock.
    private let observationRegistrar = ObservationRegistrar()

    /// Creates a `SessionPropertyValues` storage container optionally associated with `session`.
    ///
    /// - Parameter session: The owning language model session, if any.
    internal init(session: LanguageModelSession? = nil) {
      self.state = Mutex(State(session: session))
    }

    /// The owning session, loaded under lock and returned without holding the lock.
    private var session: LanguageModelSession? {
      state.withLock { $0.session }
    }

    /// Synthetic subscript used to form distinct `KeyPath` instances per `SessionPropertyKey`
    /// metatype for `ObservationRegistrar` tracking.
    private subscript(observationKey keyID: ObjectIdentifier) -> (any Sendable)? {
      nil
    }

    /// Accesses the property value associated with the specified key type.
    ///
    /// - Parameter key: The session property key type.
    /// - Returns: The stored value for `key`, or its default value if unset.
    @inline(__always)
    public final subscript<K: SessionPropertyKey>(key: K.Type) -> K.Value {
      get {
        let keyID = ObjectIdentifier(key)
        observationRegistrar.access(self, keyPath: \.[observationKey: keyID])
        if let stored = state.withLock({ $0.storage[keyID] }) as? K.Value {
          return stored
        }
        return K.defaultValue
      }
      set {
        let keyID = ObjectIdentifier(key)
        observationRegistrar.withMutation(of: self, keyPath: \.[observationKey: keyID]) {
          state.withLock { state in
            state.storage[keyID] = newValue
          }
        }
      }
    }

    /// The mutable transcript history view of the associated session.
    public final var history: Transcript.HistoryView {
      get {
        observationRegistrar.access(self, keyPath: \.history)
        return session?.transcript.history ?? Transcript.HistoryView()
      }
      set {
        guard !Self.isExecutingToolCall, let session else { return }
        if Self.isInHistoryWriteScope {
          observationRegistrar.withMutation(of: self, keyPath: \.history) {
            session.mutateState(notifying: \.transcript) { state in
              state.transcript.history = newValue
            }
          }
        } else {
          observationRegistrar.withMutation(of: self, keyPath: \.history) {
            session.transcript.history = newValue
          }
        }
      }
    }

    /// The full transcript of the owning session, or an empty transcript when unbound.
    internal final var transcript: Transcript {
      observationRegistrar.access(self, keyPath: \.transcript)
      return session?.transcript ?? Transcript()
    }
  }

  extension SessionPropertyValues: nonisolated Observable {}

  // MARK: - LanguageModelSession.SessionProperty

  extension LanguageModelSession {
    /// A property wrapper that reads and writes one entry of a session's ``SessionPropertyValues``.
    ///
    /// - SeeAlso: [`LanguageModelSession.SessionProperty`](https://developer.apple.com/documentation/foundationmodels/languagemodelsession/sessionproperty)
    @propertyWrapper
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public struct SessionProperty<Value> {
      /// Reference box holding the bound `SessionPropertyValues` instance so copies of a bound
      /// `SessionProperty` share the same session binding.
      internal final class StorageBox: Sendable {
        /// The binding state of a storage box.
        private struct State: Sendable {
          /// The bound `SessionPropertyValues` instance, or `nil` if unbound.
          var values: SessionPropertyValues?

          /// The name of the class that declares the wrapper, if it was found in a class.
          var enclosingClassName: String?
        }

        /// Mutex guarding the binding state.
        private let state = Mutex(State())

        /// Creates an unbound storage box.
        init() {}

        /// The bound `SessionPropertyValues` instance, or `nil` if unbound.
        ///
        /// Traps if the wrapper is declared in a class, because session properties are supported
        /// only in structs.
        var values: SessionPropertyValues? {
          let (values, enclosingClassName) = state.withLock { ($0.values, $0.enclosingClassName) }
          if let enclosingClassName {
            fatalError(
              "@SessionProperty is supported only in structs, but '\(enclosingClassName)' is a class."
            )
          }
          return values
        }

        /// Binds this storage box to `values`.
        ///
        /// - Parameter values: The session property values instance to bind to.
        func bind(to values: SessionPropertyValues) {
          state.withLock { $0.values = values }
        }

        /// Records that the wrapper is declared in the class named `className`.
        ///
        /// - Parameter className: The name of the enclosing class.
        func markDeclared(inClassNamed className: String) {
          state.withLock { $0.enclosingClassName = className }
        }
      }

      /// Closure that reads the property value from a `SessionPropertyValues` instance.
      private let getter: @Sendable (SessionPropertyValues) -> Value

      /// Closure that writes a new property value to a `SessionPropertyValues` instance.
      private let setter: @Sendable (SessionPropertyValues, Value) -> Void

      /// The reference box storing the bound session's `SessionPropertyValues`.
      internal let storage = StorageBox()

      /// Creates a session property wrapper accessing the property at the given key path.
      ///
      /// - Parameter keyPath: A reference-writable key path into ``SessionPropertyValues``.
      public init(_ keyPath: ReferenceWritableKeyPath<SessionPropertyValues, Value>) {
        nonisolated(unsafe) let sendableKeyPath = keyPath
        self.getter = { values in
          unsafe values[keyPath: sendableKeyPath]
        }
        self.setter = { values, newValue in
          unsafe values[keyPath: sendableKeyPath] = newValue
        }
      }

      /// Creates a read-only session property wrapper that accesses the value at `keyPath`.
      ///
      /// - Parameter keyPath: A key path to a property on ``SessionPropertyValues``.
      internal init(_ keyPath: KeyPath<SessionPropertyValues, Value>) {
        nonisolated(unsafe) let sendableKeyPath = keyPath
        self.getter = { values in
          unsafe values[keyPath: sendableKeyPath]
        }
        self.setter = { _, _ in }
      }

      /// The underlying property value stored in the bound session.
      public var wrappedValue: Value {
        get {
          let values = storage.values ?? SessionPropertyValues(session: nil)
          return getter(values)
        }
        nonmutating set {
          guard let values = storage.values else { return }
          setter(values, newValue)
        }
      }
    }
  }

  @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
  @available(tvOS, unavailable)
  extension LanguageModelSession.SessionProperty: Sendable where Value: Sendable {}

  extension Tool {
    /// An alias for the session property wrapper accessible within a tool.
    @available(iOS 27.0, macOS 27.0, visionOS 27.0, watchOS 27.0, *)
    @available(tvOS, unavailable)
    public typealias SessionProperty<Value> = LanguageModelSession.SessionProperty<Value>
  }

  // MARK: - Internal Reflection Binder

  /// An internal protocol for property wrappers that can be bound to a session's
  /// `SessionPropertyValues` storage.
  internal protocol _SessionPropertyBindable {
    /// Binds this property wrapper to `values`.
    ///
    /// - Parameter values: The session property values instance to bind to.
    func _bind(to values: SessionPropertyValues)

    /// Records that this property wrapper is declared in the class named `className`.
    ///
    /// - Parameter className: The name of the enclosing class.
    func _markDeclared(inClassNamed className: String)
  }

  extension LanguageModelSession.SessionProperty: _SessionPropertyBindable {
    /// Binds this property wrapper's underlying storage box to `values`.
    ///
    /// - Parameter values: The session property values instance to bind to.
    internal func _bind(to values: SessionPropertyValues) {
      storage.bind(to: values)
    }

    /// Records that this property wrapper is declared in the class named `className`.
    ///
    /// - Parameter className: The name of the enclosing class.
    internal func _markDeclared(inClassNamed className: String) {
      storage.markDeclared(inClassNamed: className)
    }
  }

  /// Recursively inspects values via `Mirror` reflection to bind `@SessionProperty` wrappers to a
  /// session's `SessionPropertyValues`.
  internal enum SessionPropertyBinder {
    /// Recursively walks `root` and binds every encountered `SessionProperty` wrapper to `values`.
    ///
    /// - Parameters:
    ///   - root: The root value (such as a profile, instructions, modifier, tool, or tool array).
    ///   - values: The session property values instance to bind discovered wrappers to.
    internal static func bind(_ root: Any, to values: SessionPropertyValues) {
      if let bindable = root as? any _SessionPropertyBindable {
        bindable._bind(to: values)
        return
      }
      if isKnownLeaf(root) {
        return
      }
      if type(of: root) is AnyObject.Type {
        // Session properties are supported only in structs. Mark any wrappers declared in the
        // class or its superclasses so that accessing them traps, without walking further into the
        // object graph.
        let className = String(describing: type(of: root))
        var classMirror: Mirror? = Mirror(reflecting: root)
        while let currentMirror = classMirror {
          for child in currentMirror.children {
            if let bindable = child.value as? any _SessionPropertyBindable {
              bindable._markDeclared(inClassNamed: className)
            }
          }
          classMirror = currentMirror.superclassMirror
        }
        return
      }
      let mirror = Mirror(reflecting: root)
      if let displayStyle = mirror.displayStyle {
        switch displayStyle {
        case .struct, .tuple, .optional, .collection, .set, .dictionary, .enum:
          break
        default:
          return
        }
      }
      for child in mirror.children {
        bind(child.value, to: values)
      }
    }

    /// Returns `true` if `value` is a known primitive or leaf value type that cannot contain a
    /// `SessionProperty` child.
    ///
    /// - Parameter value: The value to check.
    /// - Returns: Whether `value` can be skipped without reflection.
    private static func isKnownLeaf(_ value: Any) -> Bool {
      switch value {
      case is String, is Substring, is Character,
        is Int, is Int8, is Int16, is Int32, is Int64,
        is UInt, is UInt8, is UInt16, is UInt32, is UInt64,
        is Double, is Float, is Bool,
        is UUID, is Data, is Date, is URL, is Decimal,
        is GenerationSchema, is GenerationOptions, is ContextOptions,
        is Transcript, is Transcript.Entry, is Transcript.HistoryView,
        is Instructions, is Prompt, is LanguageModelCapabilities:
        return true
      default:
        return false
      }
    }
  }
#endif  // compiler(>=6.4)
