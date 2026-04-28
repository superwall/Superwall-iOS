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
  func `simple email`() {
    #expect(Email("user@example.com") != nil)
  }

  @Test("accepts email with dots in local part")
  func `dotted local part`() {
    #expect(Email("first.last@domain.co") != nil)
  }

  @Test("accepts email with plus tag")
  func `plus tag`() {
    #expect(Email("user+tag@example.com") != nil)
  }

  @Test("accepts email with subdomain")
  func `subdomain`() {
    #expect(Email("user@mail.example.co.uk") != nil)
  }

  @Test("accepts email with numbers")
  func `numbers`() {
    #expect(Email("user123@domain456.com") != nil)
  }

  @Test("accepts email with hyphen in domain")
  func `hyphenated domain`() {
    #expect(Email("user@my-domain.com") != nil)
  }

  @Test("accepts email with underscore and percent")
  func `underscore and percent`() {
    #expect(Email("user_%name@domain.org") != nil)
  }

  @Test("preserves the raw value on success")
  func `preserves raw value`() {
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
  func `rejects invalid value`(value: String) {
    #expect(Email(value) == nil)
  }

  // MARK: - Equatable

  @Test("two emails with the same address are equal")
  func `equal emails`() {
    #expect(Email("a@b.com") == Email("a@b.com"))
  }

  @Test("two emails with different addresses are not equal")
  func `different emails`() {
    #expect(Email("a@b.com") != Email("x@y.com"))
  }
}

// MARK: - sanitizeAttribute

@Suite("Superwall.sanitizeAttribute")
struct SanitizeAttributeTests {

  @Test("passes a valid email through unchanged")
  func `valid email passes through`() {
    let result = Superwall.sanitizeAttribute(key: "email", value: "user@example.com")
    #expect(result as? String == "user@example.com")
  }

  @Test("replaces the placeholder 'none' with nil for the email key")
  func `none placeholder becomes nil`() {
    let result = Superwall.sanitizeAttribute(key: "email", value: "none")
    #expect(result == nil)
  }

  @Test("replaces an empty string with nil for the email key")
  func `empty string becomes nil`() {
    let result = Superwall.sanitizeAttribute(key: "email", value: "")
    #expect(result == nil)
  }

  @Test("does not sanitize non-email keys")
  func `non email key untouched`() {
    let result = Superwall.sanitizeAttribute(key: "name", value: "none")
    #expect(result as? String == "none")
  }

  @Test("does not sanitize non-string values on the email key")
  func `non string value untouched`() {
    let result = Superwall.sanitizeAttribute(key: "email", value: 42)
    #expect(result as? Int == 42)
  }

  @Test("passes nil through unchanged")
  func `nil value passes through`() {
    let result = Superwall.sanitizeAttribute(key: "email", value: nil)
    #expect(result == nil)
  }
}
