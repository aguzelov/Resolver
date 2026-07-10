//
//  ResolverTests.swift
//  ResolverTests
//
//  NOTE: `Resolver.shared` is a process-wide singleton with no reset hook, and
//  every registration made in any test persists for the lifetime of the test
//  run. To keep tests independent, each test below resolves using a unique
//  `name` (rather than relying on unnamed resolution, which would search
//  across every container ever registered by any test).
//

import XCTest
@testable import Resolver

final class ResolverTests: XCTestCase {

	func test_shared_isSingleton() {
		XCTAssertTrue(Resolver.shared === Resolver.shared)
	}

	func test_register_resolvesServiceFromNamedScope() {
		let scope = uniqueScope()
		let name = UUID().uuidString
		Resolver.shared.register(scope) { container in
			container.register(ServiceProtocol.self, name: name, lifetime: .container) { _ in ServiceA() }
		}

		let resolved: ServiceProtocol = Resolver.shared.resolve(ServiceProtocol.self, name: name)
		XCTAssertTrue(resolved is ServiceA)
	}

	func test_register_calledTwiceWithSameScope_reusesSameContainer() {
		let scope = uniqueScope()
		let serviceName = UUID().uuidString
		let otherName = UUID().uuidString

		Resolver.shared.register(scope) { container in
			container.register(ServiceProtocol.self, name: serviceName, lifetime: .container) { _ in ServiceA() }
		}
		Resolver.shared.register(scope) { container in
			container.register(OtherServiceProtocol.self, name: otherName, lifetime: .transient) { _ in OtherService() }
		}

		let service: ServiceProtocol = Resolver.shared.resolve(ServiceProtocol.self, name: serviceName)
		let other: OtherServiceProtocol = Resolver.shared.resolve(OtherServiceProtocol.self, name: otherName)

		XCTAssertTrue(service is ServiceA)
		XCTAssertTrue(other is OtherService)
	}

	func test_resolve_namedService_throughSharedResolver() {
		let scope = uniqueScope()
		let name = UUID().uuidString
		Resolver.shared.register(scope) { container in
			container.register(ServiceProtocol.self, name: name, lifetime: .container) { _ in ServiceB() }
		}

		let resolved: ServiceProtocol = Resolver.shared.resolve(ServiceProtocol.self, name: name)
		XCTAssertTrue(resolved is ServiceB)
	}

	func test_resolve_findsRegistrationInFirstMatchingContainer() {
		let firstScope = uniqueScope("first")
		let secondScope = uniqueScope("second")
		// A single name shared by both containers, unique to this test, so the
		// only two containers holding this (type, name) pair are the ones
		// registered right here.
		let sharedName = UUID().uuidString

		// Register the "second" scope's container first, so it is inserted
		// before the "first" scope container in the resolver's internal list.
		Resolver.shared.register(secondScope) { container in
			container.register(ServiceProtocol.self, name: sharedName, lifetime: .container) { _ in ServiceB() }
		}
		Resolver.shared.register(firstScope) { container in
			container.register(ServiceProtocol.self, name: sharedName, lifetime: .container) { _ in ServiceA() }
		}

		// Both containers register the same type+name; the resolver should
		// return whichever container was registered first (search order), which
		// here is the "second" scope's container.
		let resolved: ServiceProtocol = Resolver.shared.resolve(ServiceProtocol.self, name: sharedName)
		XCTAssertTrue(resolved is ServiceB)
	}

	func test_serviceBuilder_receivesContainerWithMatchingScope() {
		let scope = uniqueScope()
		var capturedScope: String?

		Resolver.shared.register(scope) { container in
			capturedScope = container.scope
			container.register(ServiceProtocol.self, name: UUID().uuidString, lifetime: .transient) { _ in ServiceA() }
		}

		XCTAssertEqual(capturedScope, scope)
	}

	func test_concurrentRegisterAndResolve_acrossDistinctScopes_doesNotCrash() {
		let iterations = 50
		let expectation = expectation(description: "all concurrent operations complete")
		expectation.expectedFulfillmentCount = iterations

		DispatchQueue.concurrentPerform(iterations: iterations) { index in
			let scope = uniqueScope("concurrent-\(index)")
			let name = UUID().uuidString
			Resolver.shared.register(scope) { container in
				container.register(ServiceProtocol.self, name: name, lifetime: .container) { _ in ServiceA() }
			}
			let resolved: ServiceProtocol = Resolver.shared.resolve(ServiceProtocol.self, name: name)
			XCTAssertTrue(resolved is ServiceA)
			expectation.fulfill()
		}

		waitForExpectations(timeout: 5)
	}
}
