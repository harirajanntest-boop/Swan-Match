import 'package:flutter/widgets.dart';

/// App-wide `RouteObserver`, registered on `MaterialApp.navigatorObservers`.
/// Lets any page implement `RouteAware` to know when it's been covered by a
/// pushed route (e.g. `SwipePage` pausing its active video when the user
/// taps into `MatchProfileDetailPage`) and when it becomes visible again.
final RouteObserver<PageRoute<dynamic>> appRouteObserver =
    RouteObserver<PageRoute<dynamic>>();
