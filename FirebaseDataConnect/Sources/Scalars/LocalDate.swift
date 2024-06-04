//
//  File.swift
//  
//
//  Created by Aashish Patil on 6/1/24.
//

import Foundation

/*
 LocalDate represents an ISO-8601 formatted date without time components.

 Essentially represents: https://the-guild.dev/graphql/scalars/docs/scalars/local-date
 */
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public struct LocalDate: Codable, Equatable, CustomStringConvertible {

  private var calendar = Calendar(identifier: .gregorian)
  private var dateFormatter = DateFormatter()
  private var date = Date()

  private let components: Set<Calendar.Component> = [.year, .month, .day]

  // default initializing here to suppress a false compiler error of "used before initializing"
  // the date components will get actually initialized in various initializers.
  private var dateComponents: DateComponents = DateComponents()

  public init(year: Int, month: Int, day: Int) throws {
    dateComponents = DateComponents(year: year, month: month , day: day)
    dateComponents.calendar = calendar
    guard dateComponents.isValidDate,
            let date = dateComponents.date else {
      throw DataConnectError.invalidLocalDateFormat
    }
    self.date = date
    
    setupDateFormat()
  }

  public init(date: Date) {
    self.dateComponents = calendar.dateComponents(components, from: date)
    self.date = calendar.date(from: self.dateComponents)!

    setupDateFormat()
  }

  // localDateString of format: YYYY-MM-DD
  public init(localDateString: String) throws {
    setupDateFormat()

    self.date = try convert(dateString: localDateString)
    self.dateComponents = calendar.dateComponents(components, from: self.date)
  }

  public var description: String {
    return dateFormatter.string(from: self.date)
  }

  // MARK: Private
  private func setupDateFormat() {
    dateFormatter.dateFormat = "yyyy-MM-dd"
  }

  private func convert(dateString: String) throws -> Date  {
    guard let date = dateFormatter.date(from: dateString) else {
      throw DataConnectError.invalidLocalDateFormat
    }
    return date
  }
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension LocalDate: Codable {
  public init(from decoder: any Decoder) throws {

    let container = try decoder.singleValueContainer()
    let localDateString = try container.decode(String.self)

    setupDateFormat()
    self.date = try convert(dateString: localDateString)
    self.dateComponents = calendar.dateComponents(components, from: self.date)
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    let formattedDate = dateFormatter.string(from: self.date)
    try container.encode(formattedDate)
  }
}

// MARK: Equatable, Comparable
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension LocalDate: Comparable, Equatable {
  public static func < (lhs: LocalDate, rhs: LocalDate) -> Bool {
    return lhs.date < rhs.date
  }

  public static func == (lhs: LocalDate, rhs: LocalDate) -> Bool {
    return lhs.date == rhs.date
  }
}

// MARK: Hashable
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension LocalDate: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(self.date)
  }
}
