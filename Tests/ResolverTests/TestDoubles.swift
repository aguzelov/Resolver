//
//  TestDoubles.swift
//  ResolverTests
//

import Foundation
@testable import Resolver

protocol ServiceProtocol {
	var id: UUID { get }
}

final class ServiceA: ServiceProtocol {
	let id = UUID()
}

final class ServiceB: ServiceProtocol {
	let id = UUID()
}

final class DependentService {
	let id = UUID()
	let dependency: ServiceProtocol

	init(dependency: ServiceProtocol) {
		self.dependency = dependency
	}
}

protocol OtherServiceProtocol {
	var id: UUID { get }
}

final class OtherService: OtherServiceProtocol {
	let id = UUID()
}

/// Thread-safe counter used to verify how many times a factory closure runs.
final class CallCounter {
	private let lock = NSLock()
	private var _count = 0

	var count: Int {
		lock.withLock { _count }
	}

	@discardableResult
	func increment() -> Int {
		lock.withLock {
			_count += 1
			return _count
		}
	}
}

func uniqueScope(_ name: String = #function) -> String {
	"\(name)-\(UUID().uuidString)"
}
