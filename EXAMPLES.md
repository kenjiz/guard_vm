# Guard VM - Complex Use Cases & Examples

This document demonstrates how to use `guard_vm` for complex, production-grade applications, including state machines and real-world scenarios.

## Table of Contents

- [State Machine Use Cases](#state-machine-use-cases)
  - [Multi-Step Checkout Flow](#1-multi-step-checkout-flow)
  - [Video/Audio Player](#2-videoaudio-player)
  - [Authentication with MFA](#3-authentication-with-mfa)
  - [File Upload with Validation](#4-file-upload-with-validation)
  - [Banking Transaction Flow](#5-banking-transaction-flow)
- [Production App: Ride-Hailing Service](#production-example-ride-hailing-app)
  - [Architecture Overview](#architecture-overview)
  - [Location Tracking](#1-location-tracking)
  - [Ride Booking Flow](#2-ride-booking-flow)
  - [Active Ride Management](#3-active-ride-state)
  - [Payment Processing](#4-payment-processing)
  - [Rating System](#5-rating-system)
  - [Ride History](#6-ride-history-with-pagination)
  - [App Coordination](#7-app-coordinator)
  - [UI Integration](#8-ui-implementation)
  - [Offline Support](#9-offline-support)
  - [Testing](#10-testing)

---

## State Machine Use Cases

These examples show when and how to use state machines with `guard_vm`.

### 1. Multi-Step Checkout Flow

**Use Case:** E-commerce checkout with multiple required steps that must be completed in order.

```dart
sealed class CheckoutStep {}

class ShippingAddressStep extends CheckoutStep {
  final Address? savedAddress;
  final bool isEditing;

  ShippingAddressStep({this.savedAddress, this.isEditing = false});
}

class ShippingMethodStep extends CheckoutStep {
  final Address confirmedAddress;  // ← Can't proceed without address
  final List<ShippingMethod> availableMethods;

  ShippingMethodStep(this.confirmedAddress, this.availableMethods);
}

class PaymentMethodStep extends CheckoutStep {
  final Address confirmedAddress;
  final ShippingMethod confirmedShipping;

  PaymentMethodStep(this.confirmedAddress, this.confirmedShipping);
}

class OrderReviewStep extends CheckoutStep {
  final Address address;
  final ShippingMethod shipping;
  final PaymentMethod payment;
  final bool isSubmitting;

  OrderReviewStep(this.address, this.shipping, this.payment, {
    this.isSubmitting = false,
  });
}

class OrderSubmittedStep extends CheckoutStep {
  final Order order;
  OrderSubmittedStep(this.order);
}

// ViewModel enforces step order
class CheckoutVM extends GuardVM<CheckoutStep> {
  CheckoutVM() : super(const AsyncValue.loading());

  Future<void> loadShippingStep() => guard(() async {
    final savedAddress = await _addressRepo.getSavedAddress();
    return ShippingAddressStep(savedAddress: savedAddress);
  });

  Future<void> confirmShipping(Address address) => guardUpdate((current) async {
    // Validate we're on the right step
    if (current is! ShippingAddressStep) {
      throw Exception('Invalid transition: must complete address first');
    }

    final methods = await _shippingRepo.getAvailableMethods(address);
    return ShippingMethodStep(address, methods);
  });

  Future<void> selectShippingMethod(ShippingMethod method) => guardUpdate((current) async {
    if (current is! ShippingMethodStep) {
      throw Exception('Invalid transition: select shipping first');
    }

    return PaymentMethodStep(current.confirmedAddress, method);
  });

  Future<void> submitOrder() => guardOptimistic(
    optimisticState: (() {
      final current = value.value as OrderReviewStep;
      return OrderReviewStep(
        current.address,
        current.shipping,
        current.payment,
        isSubmitting: true,
      );
    })(),
    action: () async {
      final current = value.value as OrderReviewStep;
      final order = await _orderRepo.submitOrder(
        address: current.address,
        shipping: current.shipping,
        payment: current.payment,
      );
      return OrderSubmittedStep(order);
    },
  );
}

// UI with pattern matching
class CheckoutScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GuardValueListenableBuilder<CheckoutStep>(
      listenable: checkoutVM,
      data: (context, step) => switch (step) {
        ShippingAddressStep() => ShippingAddressForm(step: step),
        ShippingMethodStep() => ShippingMethodSelector(step: step),
        PaymentMethodStep() => PaymentMethodForm(step: step),
        OrderReviewStep() => OrderReviewWidget(step: step),
        OrderSubmittedStep() => OrderSuccessWidget(step: step),
      },
    );
  }
}
```

**Key Benefits:**

- ✅ Can't skip steps (enforced by type system)
- ✅ Each step has required data from previous steps
- ✅ Clean UI with exhaustive pattern matching
- ✅ Automatic loading/error handling

---

### 2. Video/Audio Player

**Use Case:** Media player with complex state transitions and real-time position updates.

```dart
sealed class PlayerStep {}

class PlayerIdle extends PlayerStep {}

class PlayerLoading extends PlayerStep {
  final String url;
  final Duration? lastPosition;
  PlayerLoading(this.url, [this.lastPosition]);
}

class PlayerReady extends PlayerStep {
  final Duration duration;
  final VideoQuality quality;
  PlayerReady(this.duration, this.quality);
}

class PlayerPlaying extends PlayerStep {
  final Duration position;
  final Duration duration;
  final double playbackSpeed;
  final bool isBuffering;

  PlayerPlaying(
    this.position,
    this.duration, {
    this.playbackSpeed = 1.0,
    this.isBuffering = false,
  });

  PlayerPlaying copyWith({bool? isBuffering}) => PlayerPlaying(
    position,
    duration,
    playbackSpeed: playbackSpeed,
    isBuffering: isBuffering ?? this.isBuffering,
  );
}

class PlayerPaused extends PlayerStep {
  final Duration position;
  final Duration duration;
  PlayerPaused(this.position, this.duration);
}

class PlayerEnded extends PlayerStep {
  final Duration duration;
  PlayerEnded(this.duration);
}

// Use StreamGuardVM for real-time position updates
class VideoPlayerVM extends StreamGuardVM<PlayerStep> {
  VideoPlayerVM() : super(const AsyncValue.data(PlayerIdle()));

  Future<void> loadVideo(String url) => guard(() async {
    final metadata = await _player.load(url);
    return PlayerReady(metadata.duration, metadata.quality);
  });

  Future<void> play() => guardUpdate((current) async {
    if (current is PlayerReady) {
      _startPositionStream();
      return PlayerPlaying(Duration.zero, current.duration);
    }
    if (current is PlayerPaused) {
      _startPositionStream();
      return PlayerPlaying(current.position, current.duration);
    }
    throw Exception('Cannot play from current state');
  });

  void pause() {
    final current = value.value;
    if (current is PlayerPlaying) {
      _stopPositionStream();
      setData(PlayerPaused(current.position, current.duration));
    }
  }

  void _startPositionStream() {
    guardStream(_player.positionStream, (position) {
      final current = value.value;
      if (current is PlayerPlaying) {
        setData(PlayerPlaying(
          position,
          current.duration,
          playbackSpeed: current.playbackSpeed,
          isBuffering: current.isBuffering,
        ));
      }
    });
  }

  void onBuffering(bool buffering) {
    final current = value.value;
    if (current is PlayerPlaying) {
      setData(current.copyWith(isBuffering: buffering));
    }
  }
}
```

---

### 3. Authentication with MFA

**Use Case:** Secure authentication flow with multi-factor authentication.

```dart
sealed class AuthStep {}

class Unauthenticated extends AuthStep {}

class AuthenticatingPassword extends AuthStep {
  final String email;
  AuthenticatingPassword(this.email);
}

class MfaRequired extends AuthStep {
  final String email;
  final String tempToken;
  final MfaMethod method;
  final int attemptsRemaining;

  MfaRequired(this.email, this.tempToken, this.method, this.attemptsRemaining);
}

class Authenticated extends AuthStep {
  final User user;
  final String accessToken;
  Authenticated(this.user, this.accessToken);
}

class AuthVM extends GuardVM<AuthStep> {
  AuthVM() : super(const AsyncValue.data(Unauthenticated()));

  Future<void> loginWithPassword(String email, String password) => guard(() async {
    final response = await _authRepo.login(email, password);

    if (response.requiresMfa) {
      return MfaRequired(
        email,
        response.tempToken!,
        response.mfaMethod!,
        3, // attempts remaining
      );
    }

    return Authenticated(response.user!, response.accessToken!);
  });

  Future<void> verifyMfaCode(String code) => guardUpdate((current) async {
    if (current is! MfaRequired) {
      throw Exception('MFA not required - invalid state');
    }

    final response = await _authRepo.verifyMfa(
      tempToken: current.tempToken,
      code: code,
    );

    return Authenticated(response.user, response.accessToken);
  });

  void logout() {
    setData(Unauthenticated());
  }
}

// UI
class AuthScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GuardValueListenableBuilder<AuthStep>(
      listenable: authVM,
      data: (context, step) => switch (step) {
        Unauthenticated() => LoginForm(),
        MfaRequired(:var attemptsRemaining) =>
          MfaForm(attemptsRemaining: attemptsRemaining),
        Authenticated(:var user) => HomeScreen(user: user),
        _ => const LoadingView(),
      },
    );
  }
}
```

**Security Benefits:**

- ✅ Can't skip MFA step
- ✅ Temp token required for MFA
- ✅ Attempts tracking
- ✅ Type-safe transitions

---

### 4. File Upload with Validation

**Use Case:** File upload with pre-validation and progress tracking.

```dart
sealed class UploadStep {}

class UploadIdle extends UploadStep {}

class FileSelected extends UploadStep {
  final File file;
  FileSelected(this.file);
}

class Validating extends UploadStep {
  final File file;
  Validating(this.file);
}

class ValidationFailed extends UploadStep {
  final File file;
  final List<String> errors;
  ValidationFailed(this.file, this.errors);
}

class ReadyToUpload extends UploadStep {
  final File file;
  final FileMetadata metadata;
  ReadyToUpload(this.file, this.metadata);
}

class Uploading extends UploadStep {
  final File file;
  final double progress;
  final int bytesUploaded;
  final int totalBytes;

  Uploading(this.file, this.progress, this.bytesUploaded, this.totalBytes);
}

class UploadComplete extends UploadStep {
  final UploadedFile result;
  UploadComplete(this.result);
}

class FileUploadVM extends StreamGuardVM<UploadStep> {
  FileUploadVM() : super(const AsyncValue.data(UploadIdle()));

  Future<void> selectFile(File file) => guard(() async {
    return FileSelected(file);
  });

  Future<void> validateFile(File file) => guard(() async {
    // Validate size, format, etc.
    final errors = await _validator.validate(file);

    if (errors.isNotEmpty) {
      return ValidationFailed(file, errors);
    }

    final metadata = await _analyzer.analyze(file);
    return ReadyToUpload(file, metadata);
  });

  Future<void> startUpload() => guardUpdate((current) async {
    if (current is! ReadyToUpload) {
      throw Exception('File not validated');
    }

    // Stream progress updates
    final uploadStream = _uploader.upload(current.file);

    UploadComplete? result;
    guardStream(uploadStream, (event) {
      if (event is UploadProgress) {
        setData(Uploading(
          current.file,
          event.percentage,
          event.bytesUploaded,
          event.totalBytes,
        ));
      } else if (event is UploadComplete) {
        result = event;
      }
    });

    await uploadStream.last;
    return result!;
  });
}
```

---

### 5. Banking Transaction Flow

**Use Case:** Secure financial transaction with validation gates.

```dart
sealed class TransferStep {}

class TransferIdle extends TransferStep {}

class EnteringAmount extends TransferStep {
  final Account fromAccount;
  final BigDecimal? amount;
  EnteringAmount(this.fromAccount, [this.amount]);
}

class ReviewingTransfer extends TransferStep {
  final TransferDetails details;
  ReviewingTransfer(this.details);
}

class RequiresSecondFactor extends TransferStep {
  final TransferDetails details;
  RequiresSecondFactor(this.details);
}

class ProcessingTransfer extends TransferStep {
  final TransferDetails details;
  ProcessingTransfer(this.details);
}

class TransferComplete extends TransferStep {
  final Transaction transaction;
  TransferComplete(this.transaction);
}

class TransferVM extends GuardVM<TransferStep> {
  TransferVM() : super(const AsyncValue.data(TransferIdle()));

  void enterAmount(Account account, BigDecimal amount) {
    setData(EnteringAmount(account, amount));
  }

  Future<void> proceedToReview(BigDecimal amount, Account toAccount) =>
    guardUpdate((current) async {
      if (current is! EnteringAmount) {
        throw Exception('Invalid state');
      }

      final fee = await _feeCalculator.calculate(amount);
      return ReviewingTransfer(TransferDetails(
        from: current.fromAccount,
        to: toAccount,
        amount: amount,
        fee: fee,
      ));
    });

  Future<void> confirmTransfer() => guardUpdate((current) async {
    if (current is! ReviewingTransfer) {
      throw Exception('Must review transfer first');
    }

    final requires2FA = await _securityService.requires2FA(current.details);

    if (requires2FA) {
      return RequiresSecondFactor(current.details);
    }

    // Process directly
    setData(ProcessingTransfer(current.details));
    final transaction = await _transferRepo.execute(current.details);
    return TransferComplete(transaction);
  });

  Future<void> verify2FA(String code) => guardUpdate((current) async {
    if (current is! RequiresSecondFactor) {
      throw Exception('2FA not required');
    }

    await _securityService.verify2FA(code);

    setData(ProcessingTransfer(current.details));
    final transaction = await _transferRepo.execute(current.details);
    return TransferComplete(transaction);
  });
}
```

**Compliance Benefits:**

- ✅ Audit trail of state transitions
- ✅ Can't bypass security checks
- ✅ Validation at each step
- ✅ Regulatory compliance ready

---

## Production Example: Ride-Hailing App

This complete example demonstrates building a production-grade ride-hailing app (like Uber/Lyft) using `guard_vm`.

### Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                      AppVM                              │
│           (CoordinatedVM - Root State)                  │
│  Coordinates: Auth, Location, Connectivity              │
└───────────────────┬─────────────────────────────────────┘
                    │
        ┌───────────┼───────────┬───────────────┐
        │           │           │               │
    ┌───▼───┐   ┌──▼───┐   ┌───▼────┐   ┌─────▼──────┐
    │AuthVM │   │Location│  │Booking │   │RideHistory │
    │       │   │   VM   │  │   VM   │   │     VM     │
    └───┬───┘   └──┬─────┘  └───┬────┘   └─────┬──────┘
        │          │            │               │
        │          │        ┌───▼────────┐      │
        │          │        │ActiveRide  │      │
        │          │        │    VM      │      │
        │          │        └───┬────────┘      │
        │          │            │               │
    ┌───▼──────────▼───────────▼───────────────▼─────┐
    │              Repository Layer                   │
    │   (Auth, Ride, Location, Payment Services)      │
    └─────────────────────────────────────────────────┘
```

### 1. Location Tracking

Real-time location updates using `StreamGuardVM`:

```dart
// User's current location
class UserLocationVM extends StreamGuardVM<LatLng> {
  UserLocationVM(this._locationService)
      : super(const AsyncValue.loading());

  final LocationService _locationService;

  void startTracking() {
    guardStream(
      _locationService.locationStream(),
      (location) {
        // Optional: cache for offline mode
        _locationCache.save(location);
      },
    );
  }

  void stopTracking() {
    dispose(); // Cancels stream subscription
  }
}

// Driver's location during ride
class DriverLocationVM extends StreamGuardVM<DriverLocation> {
  DriverLocationVM(this._rideService)
      : super(const AsyncValue.loading());

  final RideService _rideService;

  void trackDriver(String driverId) {
    guardStream(
      _rideService.trackDriverLocation(driverId),
      (location) {
        // Calculate ETA, update route
        _updateETA(location);
      },
    );
  }
}
```

### 2. Ride Booking Flow

Complex state machine with multiple steps:

```dart
sealed class BookingStep {}

class BookingIdle extends BookingStep {
  final LatLng userLocation;
  BookingIdle(this.userLocation);
}

class SelectingDestination extends BookingStep {
  final LatLng pickupLocation;
  final LatLng? destination;
  final List<PlaceSuggestion> suggestions;

  SelectingDestination(
    this.pickupLocation, {
    this.destination,
    this.suggestions = const [],
  });
}

class SelectingRideType extends BookingStep {
  final LatLng pickupLocation;
  final LatLng destination;
  final List<RideType> availableTypes;
  final Map<RideType, PriceEstimate> estimates;

  SelectingRideType(
    this.pickupLocation,
    this.destination,
    this.availableTypes,
    this.estimates,
  );
}

class SearchingForDriver extends BookingStep {
  final RideRequest request;
  final DateTime searchStartedAt;
  final int nearbyDriversCount;

  SearchingForDriver(
    this.request,
    this.searchStartedAt,
    this.nearbyDriversCount,
  );
}

class DriverFound extends BookingStep {
  final Ride ride;
  final Driver driver;
  final Duration estimatedArrival;

  DriverFound(this.ride, this.driver, this.estimatedArrival);
}

class BookingFailed extends BookingStep {
  final String reason;
  final BookingFailureType type;

  BookingFailed(this.reason, this.type);
}

// ViewModel
class RideBookingVM extends GuardVM<BookingStep> {
  RideBookingVM(
    this._rideService,
    this._locationService,
    this._pricingService,
    this._paymentService,
  ) : super(const AsyncValue.loading());

  final RideService _rideService;
  final LocationService _locationService;
  final PricingService _pricingService;
  final PaymentService _paymentService;

  Future<void> initialize() => guard(() async {
    final location = await _locationService.getCurrentLocation();
    return BookingIdle(location);
  });

  Future<void> selectDestination(LatLng destination) =>
    guardUpdate((current) async {
      if (current is! SelectingDestination && current is! BookingIdle) {
        throw Exception('Invalid state');
      }

      final pickupLocation = current is SelectingDestination
          ? current.pickupLocation
          : (current as BookingIdle).userLocation;

      // Fetch ride types and estimates in parallel
      final results = await Future.wait([
        _rideService.getAvailableRideTypes(pickupLocation, destination),
        _pricingService.getEstimates(pickupLocation, destination),
      ]);

      return SelectingRideType(
        pickupLocation,
        destination,
        results[0] as List<RideType>,
        results[1] as Map<RideType, PriceEstimate>,
      );
    });

  Future<void> confirmBooking() => guardUpdate((current) async {
    if (current is! ConfirmingBooking) {
      throw Exception('Nothing to confirm');
    }

    // Optimistic: show searching immediately
    setData(SearchingForDriver(
      current.request,
      DateTime.now(),
      0,
    ));

    try {
      final ride = await _rideService.requestRide(current.request);

      if (ride.driver == null) {
        return BookingFailed(
          'No drivers available',
          BookingFailureType.noDriversAvailable,
        );
      }

      return DriverFound(ride, ride.driver!, ride.estimatedArrival);
    } on PaymentException catch (e) {
      return BookingFailed(
        'Payment failed: ${e.message}',
        BookingFailureType.paymentFailed,
      );
    }
  });
}
```

### 3. Active Ride State

Coordinates ride state with driver location:

```dart
sealed class RideStep {}

class WaitingForDriver extends RideStep {
  final Ride ride;
  final Driver driver;
  final LatLng driverLocation;
  final Duration estimatedArrival;

  WaitingForDriver(
    this.ride,
    this.driver,
    this.driverLocation,
    this.estimatedArrival,
  );
}

class RideInProgress extends RideStep {
  final Ride ride;
  final LatLng currentLocation;
  final List<LatLng> routeTaken;
  final Duration estimatedTimeToDestination;
  final double distanceTraveled;

  RideInProgress(
    this.ride,
    this.currentLocation,
    this.routeTaken,
    this.estimatedTimeToDestination,
    this.distanceTraveled,
  );
}

class RideCompleted extends RideStep {
  final Ride ride;
  final RideSummary summary;

  RideCompleted(this.ride, this.summary);
}

// Coordinated ViewModel
class ActiveRideVM extends CoordinatedVM<RideStep> {
  ActiveRideVM(
    this._ride,
    this._driverLocationVM,
    this._rideService,
  ) : super(AsyncValue.data(WaitingForDriver(
        _ride,
        _ride.driver!,
        _ride.driver!.location,
        _ride.estimatedArrival,
      ))) {
    // Coordinate with driver location
    coordinateWith(
      _driverLocationVM,
      _onDriverLocationUpdate,
      executeImmediately: true,
    );

    // Listen to ride status updates
    _listenToRideUpdates();
  }

  final Ride _ride;
  final DriverLocationVM _driverLocationVM;
  final RideService _rideService;
  StreamSubscription<RideUpdate>? _rideUpdateSub;

  void _onDriverLocationUpdate(DriverLocation location) {
    final current = value.value;
    if (current == null) return;

    if (current is WaitingForDriver) {
      final eta = _calculateETA(location.latLng, _ride.pickupLocation);
      setData(WaitingForDriver(
        current.ride,
        current.driver,
        location.latLng,
        eta,
      ));
    } else if (current is RideInProgress) {
      final eta = _calculateETA(location.latLng, _ride.destination);
      final distance = _calculateDistance(
        current.routeTaken,
        location.latLng,
      );

      setData(RideInProgress(
        current.ride,
        location.latLng,
        [...current.routeTaken, location.latLng],
        eta,
        distance,
      ));
    }
  }

  @override
  void dispose() {
    _rideUpdateSub?.cancel();
    super.dispose();
  }
}
```

### 4. Payment Processing

```dart
sealed class PaymentStep {}

class SelectingPaymentMethod extends PaymentStep {
  final List<PaymentMethod> savedMethods;
  final PaymentMethod? selected;

  SelectingPaymentMethod(this.savedMethods, {this.selected});
}

class ProcessingPayment extends PaymentStep {
  final PaymentMethod method;
  final double amount;

  ProcessingPayment(this.method, this.amount);
}

class PaymentSuccessful extends PaymentStep {
  final PaymentReceipt receipt;
  PaymentSuccessful(this.receipt);
}

class PaymentFailed extends PaymentStep {
  final String reason;
  final bool canRetry;

  PaymentFailed(this.reason, {this.canRetry = true});
}

class PaymentVM extends GuardVM<PaymentStep> {
  PaymentVM(this._paymentService, this._ride)
      : super(const AsyncValue.loading());

  final PaymentService _paymentService;
  final Ride _ride;

  Future<void> processPayment() => guardUpdate((current) async {
    if (current is! SelectingPaymentMethod || current.selected == null) {
      throw Exception('No payment method selected');
    }

    // Optimistic update
    setData(ProcessingPayment(
      current.selected!,
      _ride.finalAmount ?? _ride.estimatedAmount,
    ));

    try {
      final receipt = await _paymentService.processPayment(
        rideId: _ride.id,
        method: current.selected!,
        amount: _ride.finalAmount ?? _ride.estimatedAmount,
      );

      return PaymentSuccessful(receipt);
    } on InsufficientFundsException {
      return PaymentFailed(
        'Insufficient funds',
        canRetry: false,
      );
    }
  });
}
```

### 5. Rating System

```dart
class RatingState {
  final int? rating;
  final String? comment;
  final List<String> selectedTags;
  final bool isSubmitting;

  const RatingState({
    this.rating,
    this.comment,
    this.selectedTags = const [],
    this.isSubmitting = false,
  });

  RatingState copyWith({
    int? rating,
    String? comment,
    List<String>? selectedTags,
    bool? isSubmitting,
  }) => RatingState(
    rating: rating ?? this.rating,
    comment: comment ?? this.comment,
    selectedTags: selectedTags ?? this.selectedTags,
    isSubmitting: isSubmitting ?? this.isSubmitting,
  );
}

class RatingVM extends GuardVM<RatingState> {
  RatingVM(this._rideService, this._ride)
      : super(const AsyncValue.data(RatingState()));

  final RideService _rideService;
  final Ride _ride;

  void setRating(int rating) {
    final current = value.value;
    if (current != null) {
      setData(current.copyWith(rating: rating));
    }
  }

  Future<void> submitRating() => guardOptimistic(
    optimisticState: value.value!.copyWith(isSubmitting: true),
    action: () async {
      final current = value.value!;

      if (current.rating == null) {
        throw Exception('Please provide a rating');
      }

      await _rideService.submitRating(
        rideId: _ride.id,
        rating: current.rating!,
        comment: current.comment,
        tags: current.selectedTags,
      );

      return current.copyWith(isSubmitting: false);
    },
  );
}
```

### 6. Ride History with Pagination

```dart
class RideHistoryVM extends PaginatedGuardVM<Ride> {
  RideHistoryVM(this._rideService)
      : super(const AsyncValue.data(PaginatedState(
          items: [],
          currentPage: 0,
          totalPages: 1,
          totalItems: 0,
        )));

  final RideService _rideService;

  Future<void> loadInitial() => guard(() async {
    return await _rideService.getRideHistory(page: 1);
  });

  Future<void> loadMore() => guardLoadMore((current) async {
    final response = await _rideService.getRideHistory(
      page: current.currentPage + 1,
    );

    return PaginatedState(
      items: [...current.items, ...response.items],
      currentPage: response.currentPage,
      totalPages: response.totalPages,
      totalItems: response.totalItems,
    );
  });
}
```

### 7. App Coordinator

Root-level state coordination:

```dart
class AppVM extends CoordinatedVM<AppState> {
  AppVM(
    this._authVM,
    this._userLocationVM,
    this._connectivityVM,
  ) : super(const AsyncValue.data(AppState.initial())) {
    // Listen to auth changes
    coordinateWith(
      _authVM,
      (authUser) => _onAuthChanged(authUser),
      executeImmediately: true,
    );

    // Listen to connectivity
    coordinateWith(
      _connectivityVM,
      (isConnected) => _onConnectivityChanged(isConnected),
      executeImmediately: true,
    );
  }

  final AuthVM _authVM;
  final UserLocationVM _userLocationVM;
  final ConnectivityVM _connectivityVM;

  void _onAuthChanged(User? user) {
    if (user != null) {
      _userLocationVM.startTracking();
      setData(value.value!.copyWith(user: user, isAuthenticated: true));
    } else {
      _userLocationVM.stopTracking();
      setData(AppState.initial());
    }
  }
}

class AppState {
  final User? user;
  final bool isAuthenticated;
  final bool isOnline;
  final LatLng? userLocation;

  const AppState({
    this.user,
    this.isAuthenticated = false,
    this.isOnline = true,
    this.userLocation,
  });

  factory AppState.initial() => const AppState();

  AppState copyWith({
    User? user,
    bool? isAuthenticated,
    bool? isOnline,
    LatLng? userLocation,
  }) => AppState(
    user: user ?? this.user,
    isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    isOnline: isOnline ?? this.isOnline,
    userLocation: userLocation ?? this.userLocation,
  );
}
```

### 8. UI Implementation

```dart
class BookingScreen extends StatefulWidget {
  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  late final RideBookingVM _bookingVM;
  late final UserLocationVM _locationVM;

  @override
  void initState() {
    super.initState();
    _locationVM = context.read<UserLocationVM>();
    _bookingVM = RideBookingVM(
      context.read<RideService>(),
      context.read<LocationService>(),
      context.read<PricingService>(),
      context.read<PaymentService>(),
    );
    _bookingVM.initialize();
    _locationVM.startTracking();
  }

  @override
  void dispose() {
    _bookingVM.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Map with user location
          GuardValueListenableBuilder<LatLng>(
            listenable: _locationVM,
            data: (context, location) => GoogleMap(
              initialCameraPosition: CameraPosition(
                target: location,
                zoom: 15,
              ),
            ),
          ),

          // Booking flow overlay
          GuardValueListenableBuilder<BookingStep>(
            listenable: _bookingVM,
            data: (context, step) => switch (step) {
              BookingIdle() => IdleBottomSheet(
                onDestinationTap: () => _bookingVM.searchDestination(''),
              ),

              SelectingRideType(:var availableTypes, :var estimates) =>
                RideTypeSelector(
                  types: availableTypes,
                  estimates: estimates,
                  onSelect: _bookingVM.selectRideType,
                ),

              SearchingForDriver(:var nearbyDriversCount) =>
                SearchingDriverSheet(
                  nearbyDrivers: nearbyDriversCount,
                  onCancel: () => _bookingVM.cancelBooking('User cancelled'),
                ),

              DriverFound(:var driver, :var estimatedArrival) =>
                DriverFoundSheet(
                  driver: driver,
                  eta: estimatedArrival,
                ),

              _ => const SizedBox.shrink(),
            },
          ),
        ],
      ),
    );
  }
}
```

### 9. Offline Support

```dart
class OfflineRideState {
  final List<Ride> cachedRides;
  final List<SyncAction> pendingSyncActions;
  final bool isSyncing;
  final DateTime? lastSyncedAt;

  const OfflineRideState({
    this.cachedRides = const [],
    this.pendingSyncActions = const [],
    this.isSyncing = false,
    this.lastSyncedAt,
  });

  OfflineRideState copyWith({
    List<Ride>? cachedRides,
    List<SyncAction>? pendingSyncActions,
    bool? isSyncing,
    DateTime? lastSyncedAt,
  }) => OfflineRideState(
    cachedRides: cachedRides ?? this.cachedRides,
    pendingSyncActions: pendingSyncActions ?? this.pendingSyncActions,
    isSyncing: isSyncing ?? this.isSyncing,
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
  );
}

class OfflineRideVM extends GuardVM<OfflineRideState> {
  OfflineRideVM(this._cacheService, this._syncService)
      : super(const AsyncValue.data(OfflineRideState()));

  final CacheService _cacheService;
  final SyncService _syncService;

  Future<void> syncWhenOnline() => guardUpdate((current) async {
    if (current.pendingSyncActions.isEmpty) return current;

    // Optimistically show syncing
    setData(current.copyWith(isSyncing: true));

    final results = await _syncService.syncPendingActions(
      current.pendingSyncActions,
    );

    await _cacheService.clearSyncedActions(results.syncedIds);
    final remaining = await _cacheService.getPendingSyncActions();

    return current.copyWith(
      pendingSyncActions: remaining,
      isSyncing: false,
      lastSyncedAt: DateTime.now(),
    );
  });
}
```

### 10. Testing

```dart
void main() {
  group('RideBookingVM', () {
    late MockRideService mockRideService;
    late RideBookingVM vm;

    setUp(() {
      mockRideService = MockRideService();
      vm = RideBookingVM(mockRideService, ...);
    });

    tearDown(() {
      vm.dispose();
    });

    test('initializes with user location', () async {
      when(() => mockLocationService.getCurrentLocation())
          .thenAnswer((_) async => LatLng(37.7749, -122.4194));

      await vm.initialize();

      expect(vm.value.hasValue, true);
      expect(vm.value.value, isA<BookingIdle>());
    });

    test('transitions through booking flow', () async {
      // Initialize
      await vm.initialize();
      expect(vm.value.value, isA<BookingIdle>());

      // Select destination
      await vm.selectDestination(LatLng(37.8044, -122.2712));
      expect(vm.value.value, isA<SelectingRideType>());

      // Select ride type
      await vm.selectRideType(RideType.regular);
      expect(vm.value.value, isA<ConfirmingBooking>());

      // Confirm booking
      await vm.confirmBooking();
      expect(vm.value.value, isA<DriverFound>());
    });

    test('handles no drivers available', () async {
      when(() => mockRideService.requestRide(any()))
          .thenAnswer((_) async => Ride.noDriver());

      await vm.confirmBooking();

      expect(vm.value.value, isA<BookingFailed>());
      expect(
        (vm.value.value as BookingFailed).type,
        BookingFailureType.noDriversAvailable,
      );
    });
  });
}
```

---

## Summary

### When to Use State Machines with guard_vm

✅ **Perfect For:**

- Multi-step workflows (checkout, onboarding, booking)
- Authentication flows (login, MFA, verification)
- Upload/download processes
- Financial transactions
- Document workflows
- Media players with complex states

🟡 **Possible But Complex:**

- Real-time collaboration
- Complex media players with many transitions

❌ **Not Recommended:**

- Games (too many rapid updates)
- High-frequency sensor data
- Frame-by-frame animations

### Key Patterns

1. **AsyncValue<StateUnion>** - Wrap your state machine in AsyncValue for automatic loading/error handling
2. **GuardVM** - Use for standard state machines
3. **StreamGuardVM** - Use for real-time updates (location, progress, streams)
4. **CoordinatedVM** - Use for VMs that depend on other VMs
5. **PaginatedGuardVM** - Use for infinite scroll lists

### Architecture Benefits

- ✅ Type-safe state transitions
- ✅ Automatic loading/error states
- ✅ Testable and maintainable
- ✅ Clear separation of concerns
- ✅ Real-time updates handled elegantly
- ✅ Optimistic updates with rollback
- ✅ Comprehensive error handling

**Your guard_vm package is production-ready for complex, real-world applications!** 🚀
