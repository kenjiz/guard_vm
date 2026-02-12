# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2026-02-12

### Added

- **`VMScope<T>`**: InheritedWidget-based widget for passing ViewModels down the widget tree without prop drilling
  - Requires explicit VM creation and disposal in State classes (no automatic lifecycle management)
  - `VMScope.of<VM>(context)` static method for accessing VMs
  - `VMScope.maybeOf<VM>(context)` for safe optional access
  - Extension methods: `context.vm<VM>()` and `context.maybeVm<VM>()` for convenience
  - Supports nested scopes for multiple VMs
  - Clear error messages when VM not found in tree
  - Comprehensive documentation with usage examples and common mistakes

### Changed

- **`CoordinatedVM<T>`**: Enhanced coordination capabilities with better control
  - Added `executeImmediately` parameter (default: `true`) to `coordinateWith()` method
    - When `true`, immediately invokes callbacks with current state of observed VM
    - When `false`, only reacts to future state changes
    - Prevents missing initial state when setting up coordination
  - Improved error handling: automatically propagates errors to coordinating VM if no `onError` handler provided
  - Added `onLoading` callback for reacting to loading states in observed VMs
  - Better documentation with real-world examples (RideCostVM, SettingsVM coordination)

## [0.1.0+1] - 2026-02-11

### Added

- Core `GuardVM<T>` with multiple guard patterns
- `StreamGuardVM<T>` for stream-based state management
- `CoordinatedVM<T>` for inter-ViewModel coordination
- `PaginatedGuardVM<T>` for infinite scroll and pagination
- `AsyncValue<T>` sealed class for type-safe async states
- `PaginatedState<T>` model for paginated data
- `Result<T>` type for explicit success/failure handling
- `GuardValueListenableBuilder<T>` widget for reactive UI
- Automatic error handling and logging
- Operation state tracking with `isExecuting`
- Optimistic updates with automatic rollback
- Comprehensive documentation and examples
- Full test suite with examples

### Features

- **guard**: Standard async with loading state
- **guardWithResult**: Async with Result return type
- **guardSilent/refresh**: Background updates without loading
- **guardUpdate**: Transform current data with rollback
- **guardOptimistic**: Immediate UI update with rollback on error
- **guardLoadMore**: Pagination load more with state tracking
- **guardStream**: Stream subscription with lifecycle management
- **coordinateWith**: Listen to other ViewModels

### Documentation

- Comprehensive README with usage examples
- API reference for all classes and methods
- Best practices and architecture guidance
- Comparison with other state management solutions
- Testing guidelines and examples

### Fixed

- Removed reference to undefined `AppException`
- Fixed naming inconsistency (StreamBaseVM → StreamGuardVM)
- Added catch-all exception handling for non-Exception errors
- Added operation tracking to prevent race conditions
- Exported widget classes in main library file

### Changed

- Improved error handling to catch all throwable types
- Enhanced state transition logging
- Better disposal checking across all operations
