//
//  ContainerTests.swift
//  ResolverTests
//

import XCTest
@testable import Resolver

final class ContainerTests: XCTestCase {

	func test_transientLifetime_returnsNewInstanceEachResolve() {
		let container = Container(scope: uniqueScope())
		container.register(ServiceProtocol.self, lifetime: .transient) { _ in ServiceA() }

		let first: ServiceProtocol = container.resolve()
		let second: ServiceProtocol = container.resolve()

		XCTAssertNotEqual(first.id, second.id)
	}

	func test_containerLifetime_returnsSameInstanceAcrossResolves() {
		let container = Container(scope: uniqueScope())
		container.register(ServiceProtocol.self, lifetime: .container) { _ in ServiceA() }

		let first: ServiceProtocol = container.resolve()
		let second: ServiceProtocol = container.resolve()

		XCTAssertEqual(first.id, second.id)
	}

	func test_defaultLifetime_isTransient() {
		let container = Container(scope: uniqueScope())
		container.register(ServiceProtocol.self) { _ in ServiceA() }

		let first: ServiceProtocol = container.resolve()
		let second: ServiceProtocol = container.resolve()

		XCTAssertNotEqual(first.id, second.id)
	}

	func test_namedRegistrations_areResolvedIndependently() {
		let container = Container(scope: uniqueScope())
		container.register(ServiceProtocol.self, name: "a", lifetime: .container) { _ in ServiceA() }
		container.register(ServiceProtocol.self, name: "b", lifetime: .container) { _ in ServiceB() }

		let a: ServiceProtocol = container.resolve(ServiceProtocol.self, name: "a")
		let b: ServiceProtocol = container.resolve(ServiceProtocol.self, name: "b")

		XCTAssertTrue(a is ServiceA)
		XCTAssertTrue(b is ServiceB)
		XCTAssertNotEqual(a.id, b.id)
	}

	func test_unnamedAndNamedRegistrations_areDistinctServices() {
		let container = Container(scope: uniqueScope())
		container.register(ServiceProtocol.self, lifetime: .container) { _ in ServiceA() }
		container.register(ServiceProtocol.self, name: "named", lifetime: .container) { _ in ServiceB() }

		let unnamed: ServiceProtocol = container.resolve()
		let named: ServiceProtocol = container.resolve(ServiceProtocol.self, name: "named")

		XCTAssertTrue(unnamed is ServiceA)
		XCTAssertTrue(named is ServiceB)
	}

	func test_differentTypes_areIndependentEvenWithSameName() {
		let container = Container(scope: uniqueScope())
		container.register(ServiceProtocol.self, name: "x", lifetime: .container) { _ in ServiceA() }
		container.register(OtherServiceProtocol.self, name: "x") { _ in OtherService() }

		XCTAssertTrue(container.contains(ServiceProtocol.self, name: "x"))
		XCTAssertTrue(container.contains(OtherServiceProtocol.self, name: "x"))

		let service: ServiceProtocol = container.resolve(ServiceProtocol.self, name: "x")
		let other: OtherServiceProtocol = container.resolve(OtherServiceProtocol.self, name: "x")

		XCTAssertTrue(service is ServiceA)
		XCTAssertTrue(other is OtherService)
	}

	func test_contains_reflectsRegistrationState() {
		let container = Container(scope: uniqueScope())
		XCTAssertFalse(container.contains(ServiceProtocol.self))

		container.register(ServiceProtocol.self) { _ in ServiceA() }
		XCTAssertTrue(container.contains(ServiceProtocol.self))

		XCTAssertFalse(container.contains(ServiceProtocol.self, name: "other"))
	}

	func test_removeRegistration_removesFactory() {
		let container = Container(scope: uniqueScope())
		container.register(ServiceProtocol.self) { _ in ServiceA() }
		XCTAssertTrue(container.contains(ServiceProtocol.self))

		container.removeRegistration(ServiceProtocol.self)
		XCTAssertFalse(container.contains(ServiceProtocol.self))
	}

	func test_removeRegistration_clearsCachedSingleton_soReRegistrationProducesFreshInstance() {
		let container = Container(scope: uniqueScope())
		container.register(ServiceProtocol.self, lifetime: .container) { _ in ServiceA() }
		let original: ServiceProtocol = container.resolve()

		container.removeRegistration(ServiceProtocol.self)
		container.register(ServiceProtocol.self, lifetime: .container) { _ in ServiceB() }
		let replacement: ServiceProtocol = container.resolve()

		XCTAssertTrue(replacement is ServiceB)
		XCTAssertNotEqual(original.id, replacement.id)
	}

	func test_reRegisteringWithoutRemoval_doesNotAffectAlreadyCachedSingleton() {
		// Documents current behavior: registering a new factory for an already-
		// resolved `.container` lifetime service does not invalidate the cached
		// singleton, since `register` never touches the `singletons` store.
		let container = Container(scope: uniqueScope())
		container.register(ServiceProtocol.self, lifetime: .container) { _ in ServiceA() }
		let first: ServiceProtocol = container.resolve()

		container.register(ServiceProtocol.self, lifetime: .container) { _ in ServiceB() }
		let second: ServiceProtocol = container.resolve()

		XCTAssertTrue(first is ServiceA)
		XCTAssertTrue(second is ServiceA)
		XCTAssertEqual(first.id, second.id)
	}

	func test_factoryReceivesResolverForNestedDependencies() {
		let container = Container(scope: uniqueScope())
		container.register(ServiceProtocol.self, lifetime: .container) { _ in ServiceA() }
		container.register(DependentService.self) { resolver in
			DependentService(dependency: resolver.resolve())
		}

		let dependent: DependentService = container.resolve()
		XCTAssertTrue(dependent.dependency is ServiceA)
	}

	func test_reentrantResolve_forNestedContainerLifetimeDependencies_doesNotDeadlock() {
		let container = Container(scope: uniqueScope())
		container.register(ServiceProtocol.self, lifetime: .container) { _ in ServiceA() }
		container.register(DependentService.self, lifetime: .container) { resolver in
			DependentService(dependency: resolver.resolve())
		}

		let expectation = expectation(description: "resolve completes without deadlock")
		DispatchQueue.global().async {
			let dependent: DependentService = container.resolve()
			XCTAssertTrue(dependent.dependency is ServiceA)
			expectation.fulfill()
		}

		waitForExpectations(timeout: 2)
	}

	func test_containerLifetime_alwaysReturnsSameInstance_underConcurrentResolves() {
		// The factory runs outside the lock (see `Container.resolve`'s comment
		// about re-entrancy), so under contention it can be invoked more than
		// once — only one of the created instances "wins" and is cached, and
		// every caller ends up with that same instance. This test documents
		// that guarantee; it intentionally does NOT assert the factory runs
		// exactly once, since that is not something the current locking
		// strategy provides.
		let container = Container(scope: uniqueScope())
		let counter = CallCounter()
		container.register(ServiceProtocol.self, lifetime: .container) { _ in
			counter.increment()
			return ServiceA()
		}

		let iterations = 100
		var results = [UUID](repeating: UUID(), count: iterations)
		let resultsLock = NSLock()

		DispatchQueue.concurrentPerform(iterations: iterations) { index in
			let instance: ServiceProtocol = container.resolve()
			resultsLock.withLock {
				results[index] = instance.id
			}
		}

		XCTAssertGreaterThanOrEqual(counter.count, 1)
		XCTAssertEqual(Set(results).count, 1)
	}

	func test_scope_isStoredOnContainer() {
		let container = Container(scope: "my-scope")
		XCTAssertEqual(container.scope, "my-scope")
	}
}
