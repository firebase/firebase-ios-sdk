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

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
final class AnyGenerationGuides: Sendable {
  let string: StringGuides?
  let integer: IntegerGuides?
  let double: DoubleGuides?
  let array: ArrayGuides?

  init(string: StringGuides? = nil,
       integer: IntegerGuides? = nil,
       double: DoubleGuides? = nil,
       array: ArrayGuides? = nil) {
    assert([string as Any?, integer, double, array].compactMap { $0 }.count <= 1)
    self.string = string
    self.integer = integer
    self.double = double
    self.array = array
  }

  static func combine<Value>(guides: [GenerationGuide<Value>]) -> AnyGenerationGuides {
    return combine(guides: guides.map { $0.wrapped })
  }

  static func combine(guides: [AnyGenerationGuides]) -> AnyGenerationGuides {
    let generationGuides = AnyGenerationGuides(
      string: StringGuides.combine(guides.compactMap { $0.string }),
      integer: IntegerGuides.combine(guides.compactMap { $0.integer }),
      double: DoubleGuides.combine(guides.compactMap { $0.double }),
      array: ArrayGuides.combine(guides.compactMap { $0.array })
    )
    assert([
      generationGuides.string as Any?,
      generationGuides.integer,
      generationGuides.double,
      generationGuides.array,
    ].compactMap { $0 }.count <= 1)

    return generationGuides
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
struct StringGuides: Sendable {
  let anyOf: [String]?

  init(anyOf: [String]? = nil) {
    self.anyOf = anyOf
  }

  static func combine(_ guides: [StringGuides]) -> StringGuides? {
    guard !guides.isEmpty else { return nil }
    var combinedAnyOf: Set<String>?

    for guide in guides {
      if let anyOf = guide.anyOf {
        if combinedAnyOf == nil {
          combinedAnyOf = Set(anyOf)
        } else {
          combinedAnyOf?.formIntersection(anyOf)
        }
      }
    }

    return StringGuides(anyOf: combinedAnyOf.map(Array.init))
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
struct IntegerGuides: Sendable {
  let minimum: Int?
  let maximum: Int?

  init(minimum: Int? = nil, maximum: Int? = nil) {
    self.minimum = minimum
    self.maximum = maximum
  }

  static func combine(_ guides: [IntegerGuides]) -> IntegerGuides? {
    guard !guides.isEmpty else { return nil }
    var minimum: Int?
    var maximum: Int?

    for guide in guides {
      if let guideMin = guide.minimum {
        minimum = max(minimum ?? guideMin, guideMin)
      }
      if let guideMax = guide.maximum {
        maximum = min(maximum ?? guideMax, guideMax)
      }
    }

    return IntegerGuides(minimum: minimum, maximum: maximum)
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
struct DoubleGuides: Sendable {
  let minimum: Double?
  let maximum: Double?

  init(minimum: Double? = nil, maximum: Double? = nil) {
    self.minimum = minimum
    self.maximum = maximum
  }

  static func combine(_ guides: [DoubleGuides]) -> DoubleGuides? {
    guard !guides.isEmpty else { return nil }
    var minimum: Double?
    var maximum: Double?

    for guide in guides {
      if let guideMin = guide.minimum {
        minimum = max(minimum ?? guideMin, guideMin)
      }
      if let guideMax = guide.maximum {
        maximum = min(maximum ?? guideMax, guideMax)
      }
    }

    return DoubleGuides(minimum: minimum, maximum: maximum)
  }
}

@available(iOS 15.0, macOS 12.0, macCatalyst 15.0, tvOS 15.0, watchOS 8.0, *)
struct ArrayGuides: Sendable {
  let minimumCount: Int?
  let maximumCount: Int?
  let element: AnyGenerationGuides?

  init(minimumCount: Int? = nil, maximumCount: Int? = nil, element: AnyGenerationGuides? = nil) {
    self.minimumCount = minimumCount
    self.maximumCount = maximumCount
    self.element = element
  }

  static func combine(_ guides: [ArrayGuides]) -> ArrayGuides? {
    guard !guides.isEmpty else { return nil }
    var minimumCount: Int?
    var maximumCount: Int?
    var elementGuides: [AnyGenerationGuides] = []

    for guide in guides {
      if let guideMin = guide.minimumCount {
        minimumCount = max(minimumCount ?? guideMin, guideMin)
      }
      if let guideMax = guide.maximumCount {
        maximumCount = min(maximumCount ?? guideMax, guideMax)
      }
      if let element = guide.element {
        elementGuides.append(element)
      }
    }

    return ArrayGuides(
      minimumCount: minimumCount,
      maximumCount: maximumCount,
      element: elementGuides.isEmpty ? nil : AnyGenerationGuides.combine(guides: elementGuides)
    )
  }
}
