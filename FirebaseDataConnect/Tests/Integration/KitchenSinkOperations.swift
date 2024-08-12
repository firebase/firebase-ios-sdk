import FirebaseDataConnect
import Foundation

// MARK: Connector Client Extension

public extension KitchenSinkClient {
  func createTestIdMutationRef(id: UUID) -> MutationRef<
    CreateTestIdMutation.Data,
    CreateTestIdMutation.Variables
  > {
    var variables = CreateTestIdMutation.Variables(id: id)

    let request = MutationRequest(operationName: "createTestId", variables: variables)
    let ref = dataConnect.mutation(
      request: request,
      resultsDataType: CreateTestIdMutation.Data.self
    )
    return ref as! MutationRef<CreateTestIdMutation.Data, CreateTestIdMutation.Variables>
  }

  func createTestAutoIdMutationRef(
  ) -> MutationRef<CreateTestAutoIdMutation.Data, CreateTestAutoIdMutation.Variables> {
    var variables = CreateTestAutoIdMutation.Variables()

    let request = MutationRequest(operationName: "createTestAutoId", variables: variables)
    let ref = dataConnect.mutation(
      request: request,
      resultsDataType: CreateTestAutoIdMutation.Data.self
    )
    return ref as! MutationRef<
      CreateTestAutoIdMutation.Data,
      CreateTestAutoIdMutation.Variables
    >
  }

  func createStandardScalarMutationRef(id: UUID,

                                       number: Int,

                                       text: String,

                                       decimal: Double)
    -> MutationRef<CreateStandardScalarMutation.Data,
      CreateStandardScalarMutation.Variables> {
    var variables = CreateStandardScalarMutation.Variables(
      id: id,
      number: number,
      text: text,
      decimal: decimal
    )

    let request = MutationRequest(operationName: "createStandardScalar", variables: variables)
    let ref = dataConnect.mutation(
      request: request,
      resultsDataType: CreateStandardScalarMutation.Data.self
    )
    return ref as! MutationRef<
      CreateStandardScalarMutation.Data,
      CreateStandardScalarMutation.Variables
    >
  }

  func createScalarBoundaryMutationRef(id: UUID,

                                       maxNumber: Int,

                                       minNumber: Int,

                                       maxDecimal: Double,

                                       minDecimal: Double)
    -> MutationRef<CreateScalarBoundaryMutation.Data,
      CreateScalarBoundaryMutation.Variables> {
    var variables = CreateScalarBoundaryMutation.Variables(
      id: id,
      maxNumber: maxNumber,
      minNumber: minNumber,
      maxDecimal: maxDecimal,
      minDecimal: minDecimal
    )

    let request = MutationRequest(operationName: "createScalarBoundary", variables: variables)
    let ref = dataConnect.mutation(
      request: request,
      resultsDataType: CreateScalarBoundaryMutation.Data.self
    )
    return ref as! MutationRef<
      CreateScalarBoundaryMutation.Data,
      CreateScalarBoundaryMutation.Variables
    >
  }

  func createLargeNumMutationRef(id: UUID,

                                 num: Int64,

                                 maxNum: Int64,

                                 minNum: Int64)
    -> MutationRef<CreateLargeNumMutation.Data,
      CreateLargeNumMutation.Variables> {
    var variables = CreateLargeNumMutation.Variables(
      id: id,
      num: num,
      maxNum: maxNum,
      minNum: minNum
    )

    let request = MutationRequest(operationName: "createLargeNum", variables: variables)
    let ref = dataConnect.mutation(
      request: request,
      resultsDataType: CreateLargeNumMutation.Data.self
    )
    return ref as! MutationRef<CreateLargeNumMutation.Data, CreateLargeNumMutation.Variables>
  }

  func createLocalDateMutationRef(id: UUID,

                                  localDate: LocalDate)
    -> MutationRef<CreateLocalDateMutation.Data,
      CreateLocalDateMutation.Variables> {
    var variables = CreateLocalDateMutation.Variables(id: id, localDate: localDate)

    let request = MutationRequest(operationName: "createLocalDate", variables: variables)
    let ref = dataConnect.mutation(
      request: request,
      resultsDataType: CreateLocalDateMutation.Data.self
    )
    return ref as! MutationRef<CreateLocalDateMutation.Data, CreateLocalDateMutation.Variables>
  }

  func getStandardScalarQueryRef(id: UUID)
    -> QueryRefObservableObject<GetStandardScalarQuery.Data,
      GetStandardScalarQuery.Variables> {
    var variables = GetStandardScalarQuery.Variables(id: id)

    let request = QueryRequest(operationName: "GetStandardScalar", variables: variables)
    let ref = dataConnect.query(
      request: request,
      resultsDataType: GetStandardScalarQuery.Data.self,
      publisher: .observableObject
    )
    return ref as! QueryRefObservableObject<
      GetStandardScalarQuery.Data,
      GetStandardScalarQuery.Variables
    >
  }

  func getScalarBoundaryQueryRef(id: UUID)
    -> QueryRefObservableObject<GetScalarBoundaryQuery.Data,
      GetScalarBoundaryQuery.Variables> {
    var variables = GetScalarBoundaryQuery.Variables(id: id)

    let request = QueryRequest(operationName: "GetScalarBoundary", variables: variables)
    let ref = dataConnect.query(
      request: request,
      resultsDataType: GetScalarBoundaryQuery.Data.self,
      publisher: .observableObject
    )
    return ref as! QueryRefObservableObject<
      GetScalarBoundaryQuery.Data,
      GetScalarBoundaryQuery.Variables
    >
  }

  func getLargeNumQueryRef(id: UUID) -> QueryRefObservableObject<
    GetLargeNumQuery.Data,
    GetLargeNumQuery.Variables
  > {
    var variables = GetLargeNumQuery.Variables(id: id)

    let request = QueryRequest(operationName: "GetLargeNum", variables: variables)
    let ref = dataConnect.query(
      request: request,
      resultsDataType: GetLargeNumQuery.Data.self,
      publisher: .observableObject
    )
    return ref as! QueryRefObservableObject<GetLargeNumQuery.Data, GetLargeNumQuery.Variables>
  }

  func getLocalDateTypeQueryRef(id: UUID) -> QueryRefObservableObject<
    GetLocalDateTypeQuery.Data,
    GetLocalDateTypeQuery.Variables
  > {
    var variables = GetLocalDateTypeQuery.Variables(id: id)

    let request = QueryRequest(operationName: "GetLocalDateType", variables: variables)
    let ref = dataConnect.query(
      request: request,
      resultsDataType: GetLocalDateTypeQuery.Data.self,
      publisher: .observableObject
    )
    return ref as! QueryRefObservableObject<
      GetLocalDateTypeQuery.Data,
      GetLocalDateTypeQuery.Variables
    >
  }
}

public enum CreateTestIdMutation {
  public static let OperationName = "createTestId"

  public typealias Ref = MutationRef<CreateTestIdMutation.Data, CreateTestIdMutation.Variables>

  public struct Variables: OperationVariable {
    public var
      id: UUID

    public init(id: UUID) {
      self.id = id
    }

    public static func == (lhs: Variables, rhs: Variables) -> Bool {
      return lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
      hasher.combine(id)
    }

    enum CodingKeys: String, CodingKey {
      case id
    }

    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      let codecHelper = CodecHelper<CodingKeys>()

      try codecHelper.encode(id, forKey: .id, container: &container)
    }
  }

  public struct Data: Decodable {
    public var
      testId_insert: TestIdKey
  }
}

public enum CreateTestAutoIdMutation {
  public static let OperationName = "createTestAutoId"

  public typealias Ref = MutationRef<
    CreateTestAutoIdMutation.Data,
    CreateTestAutoIdMutation.Variables
  >

  public struct Variables: OperationVariable {}

  public struct Data: Decodable {
    public var
      testAutoId_insert: TestAutoIdKey
  }
}

public enum CreateStandardScalarMutation {
  public static let OperationName = "createStandardScalar"

  public typealias Ref = MutationRef<
    CreateStandardScalarMutation.Data,
    CreateStandardScalarMutation.Variables
  >

  public struct Variables: OperationVariable {
    public var
      id: UUID

    public var
      number: Int

    public var
      text: String

    public var
      decimal: Double

    public init(id: UUID,

                number: Int,

                text: String,

                decimal: Double) {
      self.id = id
      self.number = number
      self.text = text
      self.decimal = decimal
    }

    public static func == (lhs: Variables, rhs: Variables) -> Bool {
      return lhs.id == rhs.id &&
        lhs.number == rhs.number &&
        lhs.text == rhs.text &&
        lhs.decimal == rhs.decimal
    }

    public func hash(into hasher: inout Hasher) {
      hasher.combine(id)

      hasher.combine(number)

      hasher.combine(text)

      hasher.combine(decimal)
    }

    enum CodingKeys: String, CodingKey {
      case id

      case number

      case text

      case decimal
    }

    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      let codecHelper = CodecHelper<CodingKeys>()

      try codecHelper.encode(id, forKey: .id, container: &container)

      try codecHelper.encode(number, forKey: .number, container: &container)

      try codecHelper.encode(text, forKey: .text, container: &container)

      try codecHelper.encode(decimal, forKey: .decimal, container: &container)
    }
  }

  public struct Data: Decodable {
    public var
      standardScalars_insert: StandardScalarsKey
  }
}

public enum CreateScalarBoundaryMutation {
  public static let OperationName = "createScalarBoundary"

  public typealias Ref = MutationRef<
    CreateScalarBoundaryMutation.Data,
    CreateScalarBoundaryMutation.Variables
  >

  public struct Variables: OperationVariable {
    public var
      id: UUID

    public var
      maxNumber: Int

    public var
      minNumber: Int

    public var
      maxDecimal: Double

    public var
      minDecimal: Double

    public init(id: UUID,

                maxNumber: Int,

                minNumber: Int,

                maxDecimal: Double,

                minDecimal: Double) {
      self.id = id
      self.maxNumber = maxNumber
      self.minNumber = minNumber
      self.maxDecimal = maxDecimal
      self.minDecimal = minDecimal
    }

    public static func == (lhs: Variables, rhs: Variables) -> Bool {
      return lhs.id == rhs.id &&
        lhs.maxNumber == rhs.maxNumber &&
        lhs.minNumber == rhs.minNumber &&
        lhs.maxDecimal == rhs.maxDecimal &&
        lhs.minDecimal == rhs.minDecimal
    }

    public func hash(into hasher: inout Hasher) {
      hasher.combine(id)

      hasher.combine(maxNumber)

      hasher.combine(minNumber)

      hasher.combine(maxDecimal)

      hasher.combine(minDecimal)
    }

    enum CodingKeys: String, CodingKey {
      case id

      case maxNumber

      case minNumber

      case maxDecimal

      case minDecimal
    }

    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      let codecHelper = CodecHelper<CodingKeys>()

      try codecHelper.encode(id, forKey: .id, container: &container)

      try codecHelper.encode(maxNumber, forKey: .maxNumber, container: &container)

      try codecHelper.encode(minNumber, forKey: .minNumber, container: &container)

      try codecHelper.encode(maxDecimal, forKey: .maxDecimal, container: &container)

      try codecHelper.encode(minDecimal, forKey: .minDecimal, container: &container)
    }
  }

  public struct Data: Decodable {
    public var
      scalarBoundary_insert: ScalarBoundaryKey
  }
}

public enum CreateLargeNumMutation {
  public static let OperationName = "createLargeNum"

  public typealias Ref = MutationRef<CreateLargeNumMutation.Data, CreateLargeNumMutation.Variables>

  public struct Variables: OperationVariable {
    public var
      id: UUID

    public var
      num: Int64

    public var
      maxNum: Int64

    public var
      minNum: Int64

    public init(id: UUID,

                num: Int64,

                maxNum: Int64,

                minNum: Int64) {
      self.id = id
      self.num = num
      self.maxNum = maxNum
      self.minNum = minNum
    }

    public static func == (lhs: Variables, rhs: Variables) -> Bool {
      return lhs.id == rhs.id &&
        lhs.num == rhs.num &&
        lhs.maxNum == rhs.maxNum &&
        lhs.minNum == rhs.minNum
    }

    public func hash(into hasher: inout Hasher) {
      hasher.combine(id)

      hasher.combine(num)

      hasher.combine(maxNum)

      hasher.combine(minNum)
    }

    enum CodingKeys: String, CodingKey {
      case id

      case num

      case maxNum

      case minNum
    }

    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      let codecHelper = CodecHelper<CodingKeys>()

      try codecHelper.encode(id, forKey: .id, container: &container)

      try codecHelper.encode(num, forKey: .num, container: &container)

      try codecHelper.encode(maxNum, forKey: .maxNum, container: &container)

      try codecHelper.encode(minNum, forKey: .minNum, container: &container)
    }
  }

  public struct Data: Decodable {
    public var
      largeIntType_insert: LargeIntTypeKey
  }
}

public enum CreateLocalDateMutation {
  public static let OperationName = "createLocalDate"

  public typealias Ref = MutationRef<
    CreateLocalDateMutation.Data,
    CreateLocalDateMutation.Variables
  >

  public struct Variables: OperationVariable {
    public var
      id: UUID

    public var
      localDate: LocalDate

    public init(id: UUID,

                localDate: LocalDate) {
      self.id = id
      self.localDate = localDate
    }

    public static func == (lhs: Variables, rhs: Variables) -> Bool {
      return lhs.id == rhs.id &&
        lhs.localDate == rhs.localDate
    }

    public func hash(into hasher: inout Hasher) {
      hasher.combine(id)

      hasher.combine(localDate)
    }

    enum CodingKeys: String, CodingKey {
      case id

      case localDate
    }

    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      let codecHelper = CodecHelper<CodingKeys>()

      try codecHelper.encode(id, forKey: .id, container: &container)

      try codecHelper.encode(localDate, forKey: .localDate, container: &container)
    }
  }

  public struct Data: Decodable {
    public var
      localDateType_insert: LocalDateTypeKey
  }
}

public enum GetStandardScalarQuery {
  public static let OperationName = "GetStandardScalar"

  public typealias Ref = QueryRefObservableObject<
    GetStandardScalarQuery.Data,
    GetStandardScalarQuery.Variables
  >

  public struct Variables: OperationVariable {
    public var
      id: UUID

    public init(id: UUID) {
      self.id = id
    }

    public static func == (lhs: Variables, rhs: Variables) -> Bool {
      return lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
      hasher.combine(id)
    }

    enum CodingKeys: String, CodingKey {
      case id
    }

    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      let codecHelper = CodecHelper<CodingKeys>()

      try codecHelper.encode(id, forKey: .id, container: &container)
    }
  }

  public struct Data: Decodable {
    public struct StandardScalars: Decodable, Hashable, Equatable, Identifiable {
      public var
        id: UUID

      public var
        number: Int

      public var
        text: String

      public var
        decimal: Double

      public var standardScalarsKey: StandardScalarsKey {
        return StandardScalarsKey(
          id: id
        )
      }

      public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
      }

      public static func == (lhs: StandardScalars, rhs: StandardScalars) -> Bool {
        return lhs.id == rhs.id
      }

      enum CodingKeys: String, CodingKey {
        case id

        case number

        case text

        case decimal
      }

      public init(from decoder: any Decoder) throws {
        var container = try decoder.container(keyedBy: CodingKeys.self)
        let codecHelper = CodecHelper<CodingKeys>()

        id = try codecHelper.decode(UUID.self, forKey: .id, container: &container)

        number = try codecHelper.decode(Int.self, forKey: .number, container: &container)

        text = try codecHelper.decode(String.self, forKey: .text, container: &container)

        decimal = try codecHelper.decode(Double.self, forKey: .decimal, container: &container)
      }
    }

    public var
      standardScalars: StandardScalars?
  }
}

public enum GetScalarBoundaryQuery {
  public static let OperationName = "GetScalarBoundary"

  public typealias Ref = QueryRefObservableObject<
    GetScalarBoundaryQuery.Data,
    GetScalarBoundaryQuery.Variables
  >

  public struct Variables: OperationVariable {
    public var
      id: UUID

    public init(id: UUID) {
      self.id = id
    }

    public static func == (lhs: Variables, rhs: Variables) -> Bool {
      return lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
      hasher.combine(id)
    }

    enum CodingKeys: String, CodingKey {
      case id
    }

    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      let codecHelper = CodecHelper<CodingKeys>()

      try codecHelper.encode(id, forKey: .id, container: &container)
    }
  }

  public struct Data: Decodable {
    public struct ScalarBoundary: Decodable {
      public var
        maxNumber: Int

      public var
        minNumber: Int

      public var
        maxDecimal: Double

      public var
        minDecimal: Double

      enum CodingKeys: String, CodingKey {
        case maxNumber

        case minNumber

        case maxDecimal

        case minDecimal
      }

      public init(from decoder: any Decoder) throws {
        var container = try decoder.container(keyedBy: CodingKeys.self)
        let codecHelper = CodecHelper<CodingKeys>()

        maxNumber = try codecHelper.decode(Int.self, forKey: .maxNumber, container: &container)

        minNumber = try codecHelper.decode(Int.self, forKey: .minNumber, container: &container)

        maxDecimal = try codecHelper.decode(Double.self, forKey: .maxDecimal, container: &container)

        minDecimal = try codecHelper.decode(Double.self, forKey: .minDecimal, container: &container)
      }
    }

    public var
      scalarBoundary: ScalarBoundary?
  }
}

public enum GetLargeNumQuery {
  public static let OperationName = "GetLargeNum"

  public typealias Ref = QueryRefObservableObject<GetLargeNumQuery.Data, GetLargeNumQuery.Variables>

  public struct Variables: OperationVariable {
    public var
      id: UUID

    public init(id: UUID) {
      self.id = id
    }

    public static func == (lhs: Variables, rhs: Variables) -> Bool {
      return lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
      hasher.combine(id)
    }

    enum CodingKeys: String, CodingKey {
      case id
    }

    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      let codecHelper = CodecHelper<CodingKeys>()

      try codecHelper.encode(id, forKey: .id, container: &container)
    }
  }

  public struct Data: Decodable {
    public struct LargeIntType: Decodable {
      public var
        num: Int64

      public var
        maxNum: Int64

      public var
        minNum: Int64

      enum CodingKeys: String, CodingKey {
        case num

        case maxNum

        case minNum
      }

      public init(from decoder: any Decoder) throws {
        var container = try decoder.container(keyedBy: CodingKeys.self)
        let codecHelper = CodecHelper<CodingKeys>()

        num = try codecHelper.decode(Int64.self, forKey: .num, container: &container)

        maxNum = try codecHelper.decode(Int64.self, forKey: .maxNum, container: &container)

        minNum = try codecHelper.decode(Int64.self, forKey: .minNum, container: &container)
      }
    }

    public var
      largeIntType: LargeIntType?
  }
}

public enum GetLocalDateTypeQuery {
  public static let OperationName = "GetLocalDateType"

  public typealias Ref = QueryRefObservableObject<
    GetLocalDateTypeQuery.Data,
    GetLocalDateTypeQuery.Variables
  >

  public struct Variables: OperationVariable {
    public var
      id: UUID

    public init(id: UUID) {
      self.id = id
    }

    public static func == (lhs: Variables, rhs: Variables) -> Bool {
      return lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
      hasher.combine(id)
    }

    enum CodingKeys: String, CodingKey {
      case id
    }

    public func encode(to encoder: Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      let codecHelper = CodecHelper<CodingKeys>()

      try codecHelper.encode(id, forKey: .id, container: &container)
    }
  }

  public struct Data: Decodable {
    public struct LocalDateType: Decodable {
      public var
        localDate: LocalDate?

      enum CodingKeys: String, CodingKey {
        case localDate
      }

      public init(from decoder: any Decoder) throws {
        var container = try decoder.container(keyedBy: CodingKeys.self)
        let codecHelper = CodecHelper<CodingKeys>()

        localDate = try codecHelper.decode(
          LocalDate?.self,
          forKey: .localDate,
          container: &container
        )
      }
    }

    public var
      localDateType: LocalDateType?
  }
}
