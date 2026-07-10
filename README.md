# Resolver

A lightweight, thread-safe dependency injection container for Swift.

Resolver lets you register factories for your types, group them into named
scopes, and resolve them later — either directly through a `Container` or
through the global `Resolver.shared` registry.

## Requirements

- Swift 5.8+
- iOS 16+ / macOS 13+

## Installation

Add Resolver as a dependency in your `Package.swift`:

```swift
dependencies: [
    .package(url: "<repository-url>", from: "1.0.0")
]
```

## Basic usage

### Registering and resolving with a `Container`

```swift
let container = Container(scope: "app")

container.register(GreeterProtocol.self) { _ in Greeter() }

let greeter: GreeterProtocol = container.resolve()
```

### Registering through the shared `Resolver`

`Resolver.shared` manages a collection of named `Container`s for you.
Calling `register(_:with:)` with a scope that already exists reuses that
container, so you can build it up across multiple call sites.

```swift
Resolver.shared.register("app") { container in
    container.register(GreeterProtocol.self) { _ in Greeter() }
}

let greeter: GreeterProtocol = Resolver.shared.resolve()
```

### Lifetimes

Each registration has a `Lifetime`:

- `.transient` (default) — a new instance is created on every `resolve()`.
- `.container` — the first resolved instance is cached and reused for the
  lifetime of the container (singleton scoped to that container).

```swift
container.register(GreeterProtocol.self, lifetime: .container) { _ in Greeter() }
```

### Named registrations

Register more than one implementation for the same type by giving each a
name:

```swift
container.register(GreeterProtocol.self, name: "formal") { _ in FormalGreeter() }
container.register(GreeterProtocol.self, name: "casual") { _ in CasualGreeter() }

let formal: GreeterProtocol = container.resolve(GreeterProtocol.self, name: "formal")
```

### Resolving dependencies of dependencies

The factory closure receives a `ResolverProtocol`, so you can resolve nested
dependencies from within it — including re-entrant calls back into the same
container:

```swift
container.register(GreetingService.self) { resolver in
    GreetingService(greeter: resolver.resolve())
}
```

### Removing a registration

```swift
container.removeRegistration(GreeterProtocol.self, name: "formal")
```

This clears both the factory and any cached singleton for that type/name.

## Notes

- Resolving a type that has no matching registration is a programmer error
  and triggers a `fatalError`.
- `Container` and `Resolver` are safe to use from multiple threads.

## Testing

Run the test suite with:

```bash
swift test
```
