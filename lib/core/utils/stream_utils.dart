import 'dart:async';

/// A safe switchMap implementation for streams that returns a **broadcast**
/// stream, allowing multiple listeners (e.g. multiple StreamBuilders in a
/// TabBarView) to subscribe simultaneously without crashing.
///
/// This solves two Flutter/Firebase stream problems:
///
/// 1. **"Bad state: Cannot add new events while doing an addStream"**
///    Caused by [Stream.asyncExpand] attempting to close a Firestore broadcast
///    stream mid-flight. Our implementation cancels the inner subscription
///    BEFORE subscribing to the next one.
///
/// 2. **"Bad state: Stream has already been listened to."**
///    Uses a broadcast controller so multiple StreamBuilders can each listen.
///
/// The outer subscription starts lazily (on first listener) and stops when
/// the last listener unsubscribes. This ensures the first data event is not
/// missed because Firebase's authStateChanges() always replays its current
/// state to new subscribers.
class _ReplayBroadcastStream<T> extends Stream<T> {
  final Stream<T> _source;
  final T? Function() _getValue;
  final bool Function() _hasValue;

  _ReplayBroadcastStream(this._source, this._getValue, this._hasValue);

  @override
  bool get isBroadcast => true;

  @override
  StreamSubscription<T> listen(
    void Function(T event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    final sc = StreamController<T>();

    // Instantly pump the cached value into this specific new listener!
    if (_hasValue()) {
      sc.add(_getValue() as T);
    }

    final sub = _source.listen(
      sc.add,
      onError: sc.addError,
      onDone: sc.close,
    );

    sc.onCancel = sub.cancel;
    sc.onPause = sub.pause;
    sc.onResume = sub.resume;

    return sc.stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

Stream<B> switchMap<A, B>(Stream<A> source, Stream<B> Function(A) mapper) {
  StreamSubscription<A>? outerSub;
  StreamSubscription<B>? innerSub;
  late StreamController<B> controller;
  
  bool hasLatest = false;
  B? latestValue;
  int listenerCount = 0;

  void stopOuter() {
    innerSub?.cancel();
    outerSub?.cancel();
    innerSub = null;
    outerSub = null;
  }

  void startOuter() {
    if (outerSub != null) return; // Already running
    
    outerSub = source.listen(
      (event) {
        innerSub?.cancel();
        innerSub = null;

        innerSub = mapper(event).listen(
          (value) {
            hasLatest = true;
            latestValue = value;
            if (!controller.isClosed) controller.add(value);
          },
          onError: (Object error, StackTrace stack) {
            if (!controller.isClosed) controller.addError(error, stack);
          },
          onDone: () => innerSub = null,
        );
      },
      onError: (Object error, StackTrace stack) {
        if (!controller.isClosed) controller.addError(error, stack);
      },
      onDone: stopOuter,
    );
  }

  controller = StreamController<B>.broadcast(
    onListen: () {
      listenerCount++;
      startOuter();
    },
    onCancel: () {
      listenerCount--;
      if (listenerCount <= 0) {
        listenerCount = 0;
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (listenerCount == 0 && !controller.isClosed) {
            stopOuter();
          }
        });
      }
    },
  );

  return _ReplayBroadcastStream<B>(
    controller.stream,
    () => latestValue,
    () => hasLatest,
  );
}
