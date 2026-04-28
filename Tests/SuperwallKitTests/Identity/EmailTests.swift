//
//  EmailTests.swift
//  SuperwallKit
//

import Testing
@testable import SuperwallKit

@Suite("Email")
struct EmailTests {

  // MARK: - Valid emails

  @Test("accepts a simple email address")
  func simpleEmail() {
    #expect(Email("user@example.com") != nil)
  }

  @Test("accepts email with dots in local part")
  func dottedLocalPart() {
    #expect(Email("first.last@domain.co") != nil)
  }

  @Test("accepts email with plus tag")
  func plusTag() {
    #expect(Email("user+tag@example.com") != nil)
  }

  @Test("accepts email with subdomain")
  func subdomain() {
    #expect(Email("user@mail.example.co.uk") != nil)
  }

  @Test("accepts email with numbers")
  func numbers() {
    #expect(Email("user123@domain456.com") != nil)
  }

  @Test("accepts email with hyphen in domain")
  func hyphenatedDomain() {
    #expect(Email("user@my-domain.com") != nil)
  }

  @Test("accepts email with underscore and percent")
  func underscoreAndPercent() {
    #expect(Email("user_%name@domain.org") != nil)
  }

  @Test("preserves the raw value on success")
  func preservesRawValue() {
    let address = "hello@world.com"
    let email = Email(address)
    #expect(email?.rawValue == address)
  }

  // MARK: - Invalid emails

  @Test(
    "rejects strings that are not valid email addresses",
    arguments: [
      "none",
      "",
      "userexample.com",
      "user@",
      "@example.com",
      "user@domain",
      "user@domain.a",
      "user @example.com",
      "not an email",
      "null",
      "N/A",
      "user@example.com\n",
    ]
  )
  func rejectsInvalidValue(value: String) {
    #expect(Email(value) == nil)
  }

  // MARK: - Equatable

  @Test("two emails with the same address are equal")
  func equalEmails() {
    #expect(Email("a@b.com") == Email("a@b.com"))
  }

  @Test("two emails with different addresses are not equal")
  func differentEmails() {
    #expect(Email("a@b.com") != Email("x@y.com"))
  }
}
