# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2026-02-12

### Added

- `VMScope<T>` that uses InheritedWidget to pass the vm down the widget tree

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
