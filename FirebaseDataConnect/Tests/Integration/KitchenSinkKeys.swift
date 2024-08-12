import Foundation

import FirebaseDataConnect

public struct LargeIntTypeKey {
  public private(set) var id: UUID

  enum CodingKeys: String, CodingKey {
    case id
  }
}

extension LargeIntTypeKey: Codable {
  public init(from decoder: any Decoder) throws {
    var container = try decoder.container(keyedBy: CodingKeys.self)
    let codecHelper = CodecHelper<CodingKeys>()

    id = try codecHelper.decode(UUID.self, forKey: .id, container: &container)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    let codecHelper = CodecHelper<CodingKeys>()

    try codecHelper.encode(id, forKey: .id, container: &container)
  }
}

extension LargeIntTypeKey: Equatable {
  public static func == (lhs: LargeIntTypeKey, rhs: LargeIntTypeKey) -> Bool {
    if lhs.id != rhs.id {
      return false
    }

    return true
  }
}

extension LargeIntTypeKey: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
}

public struct LocalDateTypeKey {
  public private(set) var id: UUID

  enum CodingKeys: String, CodingKey {
    case id
  }
}

extension LocalDateTypeKey: Codable {
  public init(from decoder: any Decoder) throws {
    var container = try decoder.container(keyedBy: CodingKeys.self)
    let codecHelper = CodecHelper<CodingKeys>()

    id = try codecHelper.decode(UUID.self, forKey: .id, container: &container)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    let codecHelper = CodecHelper<CodingKeys>()

    try codecHelper.encode(id, forKey: .id, container: &container)
  }
}

extension LocalDateTypeKey: Equatable {
  public static func == (lhs: LocalDateTypeKey, rhs: LocalDateTypeKey) -> Bool {
    if lhs.id != rhs.id {
      return false
    }

    return true
  }
}

extension LocalDateTypeKey: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
}

public struct ScalarBoundaryKey {
  public private(set) var id: UUID

  enum CodingKeys: String, CodingKey {
    case id
  }
}

extension ScalarBoundaryKey: Codable {
  public init(from decoder: any Decoder) throws {
    var container = try decoder.container(keyedBy: CodingKeys.self)
    let codecHelper = CodecHelper<CodingKeys>()

    id = try codecHelper.decode(UUID.self, forKey: .id, container: &container)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    let codecHelper = CodecHelper<CodingKeys>()

    try codecHelper.encode(id, forKey: .id, container: &container)
  }
}

extension ScalarBoundaryKey: Equatable {
  public static func == (lhs: ScalarBoundaryKey, rhs: ScalarBoundaryKey) -> Bool {
    if lhs.id != rhs.id {
      return false
    }

    return true
  }
}

extension ScalarBoundaryKey: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
}

public struct StandardScalarsKey {
  public private(set) var id: UUID

  enum CodingKeys: String, CodingKey {
    case id
  }
}

extension StandardScalarsKey: Codable {
  public init(from decoder: any Decoder) throws {
    var container = try decoder.container(keyedBy: CodingKeys.self)
    let codecHelper = CodecHelper<CodingKeys>()

    id = try codecHelper.decode(UUID.self, forKey: .id, container: &container)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    let codecHelper = CodecHelper<CodingKeys>()

    try codecHelper.encode(id, forKey: .id, container: &container)
  }
}

extension StandardScalarsKey: Equatable {
  public static func == (lhs: StandardScalarsKey, rhs: StandardScalarsKey) -> Bool {
    if lhs.id != rhs.id {
      return false
    }

    return true
  }
}

extension StandardScalarsKey: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
}

public struct TestAutoIdKey {
  public private(set) var id: UUID

  enum CodingKeys: String, CodingKey {
    case id
  }
}

extension TestAutoIdKey: Codable {
  public init(from decoder: any Decoder) throws {
    var container = try decoder.container(keyedBy: CodingKeys.self)
    let codecHelper = CodecHelper<CodingKeys>()

    id = try codecHelper.decode(UUID.self, forKey: .id, container: &container)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    let codecHelper = CodecHelper<CodingKeys>()

    try codecHelper.encode(id, forKey: .id, container: &container)
  }
}

extension TestAutoIdKey: Equatable {
  public static func == (lhs: TestAutoIdKey, rhs: TestAutoIdKey) -> Bool {
    if lhs.id != rhs.id {
      return false
    }

    return true
  }
}

extension TestAutoIdKey: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
}

public struct TestIdKey {
  public private(set) var id: UUID

  enum CodingKeys: String, CodingKey {
    case id
  }
}

extension TestIdKey: Codable {
  public init(from decoder: any Decoder) throws {
    var container = try decoder.container(keyedBy: CodingKeys.self)
    let codecHelper = CodecHelper<CodingKeys>()

    id = try codecHelper.decode(UUID.self, forKey: .id, container: &container)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    let codecHelper = CodecHelper<CodingKeys>()

    try codecHelper.encode(id, forKey: .id, container: &container)
  }
}

extension TestIdKey: Equatable {
  public static func == (lhs: TestIdKey, rhs: TestIdKey) -> Bool {
    if lhs.id != rhs.id {
      return false
    }

    return true
  }
}

extension TestIdKey: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
}
