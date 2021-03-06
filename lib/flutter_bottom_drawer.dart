library flutter_bottom_drawer;

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class BottomDrawer extends StatefulWidget {
  /// Optional widget which does not scroll with the rest of the drawer.
  final Widget header;

  /// Scrollable elements
  final List<Widget> children;

  /// Scrollable elements
  /// Used in [BottomDrawer.builder]
  final Widget Function(BuildContext, int index) itemBuilder;

  /// Elements count
  /// Used in [BottomDrawer.builder]
  final int itemCount;

  /// Values needs to be between 0.0 - 1.0. They match percentage of available drawer height
  /// [stops] length needs to be >= 2
  /// Needs to be entered in ascending order
  /// If used with [snap] then the drawer will automatically move to nearest stop after user dragging ends
  final List<double> stops;

  /// Drawer initial height
  /// Used as index in [stops]
  final int initialStopIndex;

  /// Drawer container border radius
  final BorderRadius borderRadius;

  /// Whether drawer should automatically adjust its size when user dragging ends
  /// It will move to the nearest stop in [stops]
  final bool snap;

  /// Duration of animation when [snap] triggers
  final Duration snapAnimationDuration;

  /// Whether drawer should rebuild its constraints on each build or only first time
  /// Useful if final drawer height is not available on the first drawer build
  final bool rebuildConstraints;

  /// Padding for drawer list
  final EdgeInsets listViewPadding;

  /// Drawer container shadow
  final BoxShadow shadow;

  /// Callback when user starts drag gesture
  final Function() onDragStart;

  /// Callback when user releases drag gesture
  final Function() onDragEnd;

  /// Called only if [snap] is set
  /// Callback when snap animation ends.
  /// Returns index from [stops] at which snap ended
  final Function(int) onSnapEnd;

  /// Callback when drawer height changes
  /// Returns height in pixels and in percentage of available drawer space
  final Function(double height, double heightPerc) onHeightChanged;

  /// ScrollController for embedded ListView
  final ScrollController scrollController;

  const BottomDrawer({
    this.children = const [],
    this.listViewPadding = EdgeInsets.zero,
    this.snapAnimationDuration = const Duration(milliseconds: 256),
    this.stops = const [0.2, 1.0],
    this.borderRadius,
    this.header,
    this.initialStopIndex = 0,
    this.rebuildConstraints = false,
    this.snap = true,
    this.shadow,
    this.onDragStart,
    this.onDragEnd,
    this.onSnapEnd,
    this.onHeightChanged,
    this.scrollController,
  })  : assert(initialStopIndex < stops.length, 'initialStopIndex cannot be greater than stops.length'),
        assert(stops.length >= 2, 'minimum number of stops is 2'),
        itemBuilder = null,
        itemCount = null;

  const BottomDrawer.builder({
    @required this.itemBuilder,
    this.itemCount,
    this.listViewPadding = EdgeInsets.zero,
    this.snapAnimationDuration = const Duration(milliseconds: 256),
    this.stops = const [0.2, 1.0],
    this.borderRadius,
    this.header,
    this.initialStopIndex = 0,
    this.rebuildConstraints = false,
    this.snap = true,
    this.shadow,
    this.onDragStart,
    this.onDragEnd,
    this.onSnapEnd,
    this.onHeightChanged,
    this.scrollController,
  })  : assert(initialStopIndex < stops.length, 'initialStopIndex cannot be greater than stops.length'),
        assert(stops.length >= 2, 'minimum number of stops is 2'),
        assert(itemBuilder != null, 'itemBuilder cannot be null'),
        assert(itemCount == null || itemCount >= 0, 'itemCount can either be null or positive number'),
        children = null;

  @override
  State<StatefulWidget> createState() => _BottomDrawerState();
}

class _BottomDrawerState extends State<BottomDrawer> with SingleTickerProviderStateMixin {
  ScrollController _scrollController;

  final GlobalKey _containerKey = GlobalKey();

  double currentHeight;
  double maxDrawerHeight;
  double minDrawerHeight;
  double height;
  bool dragging = false;
  bool firstTime = true;
  double lastHeight;
  int endSnapStopIndex;

  double currentScrollOffset = 0.0;
  double startScrollVelocity;
  double scrollStartOffset = 0;

  AnimationController _animationController;
  Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.scrollController ?? ScrollController();
    _animationController = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    if (widget.scrollController == null) {
      // only dispose if controller is created within this widget
      _scrollController.dispose();
    }
    _animationController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      if (firstTime) {
        height = constraints.maxHeight;
        maxDrawerHeight = widget.stops.last * height;
        minDrawerHeight = widget.stops.first * height;
        currentHeight = height * widget.stops[widget.initialStopIndex];
        lastHeight = currentHeight;
        firstTime = false;
      } else if (widget.rebuildConstraints) {
        height = constraints.maxHeight;
        maxDrawerHeight = widget.stops.last * height;
        minDrawerHeight = widget.stops.first * height;
      }

      if (lastHeight != currentHeight) {
        lastHeight = currentHeight;
        if (widget.onHeightChanged != null) widget.onHeightChanged(currentHeight, currentHeight / height);
      }

      return Align(
        alignment: Alignment.bottomCenter,
        child: AnimatedContainer(
          key: _containerKey,
          onEnd: () {
            if (!dragging && widget.snap && widget.onSnapEnd != null) {
              widget.onSnapEnd(endSnapStopIndex);
            }
          },
          duration: (dragging || !widget.snap) ? Duration.zero : widget.snapAnimationDuration,
          width: double.infinity,
          height: currentHeight,
          child: SizedBox(
            height: currentHeight,
            width: double.infinity,
            child: GestureDetector(
              onVerticalDragStart: (details) {
                _animationController.stop();
                if (widget.onDragStart != null) widget.onDragStart();
                dragging = true;
                final box = _containerKey.currentContext.findRenderObject() as RenderBox;
                currentHeight = box.size.height;
              },
              onVerticalDragUpdate: (update) {
                dragUpdate(update.primaryDelta);
              },
              onVerticalDragEnd: (details) {
                if (widget.onDragEnd != null) widget.onDragEnd();
                dragEnd(details);
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    if (widget.shadow != null) widget.shadow,
                  ],
                  borderRadius: widget.borderRadius,
                ),
                child: Column(
                  children: <Widget>[
                    if (widget.header != null) widget.header,
                    Expanded(
                      child: widget.children != null
                          ? ListView(
                              controller: _scrollController,
                              padding: widget.listViewPadding,
                              physics: NeverScrollableScrollPhysics(),
                              children: widget.children,
                            )
                          : ListView.builder(
                              controller: _scrollController,
                              padding: widget.listViewPadding,
                              physics: NeverScrollableScrollPhysics(),
                              itemBuilder: widget.itemBuilder,
                              itemCount: widget.itemCount,
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  void dragUpdate(double delta) {
    if (delta < 0 && isAtMax()) {
      _scrollController.jumpTo(
        _scrollController.position.pixels - delta,
      );
    } else if (delta > 0 && isAtMax() && _scrollController.position.pixels > 0) {
      _scrollController.jumpTo(
        _scrollController.position.pixels - delta,
      );
    } else {
      currentHeight -= delta;
      setState(() {
        if (currentHeight < minDrawerHeight) {
          currentHeight = minDrawerHeight;
        } else if (currentHeight > maxDrawerHeight) {
          currentHeight = maxDrawerHeight;
        }
      });
    }
  }

  void dragEnd(DragEndDetails details) {
    dragging = false;
    if (widget.snap == true) {
      double endStop;
      double lastStop = widget.stops.first;
      for (double stop in widget.stops) {
        if (lastStop == stop) continue;
        if (currentHeight <= stop * height) {
          if (currentHeight >= (stop - lastStop) / 2 * height + lastStop * height) {
            endStop = stop;
            break;
          } else {
            endStop = lastStop;
            break;
          }
        } else {
          lastStop = stop;
        }
      }

      if (isAtMax()) {
        if (details.primaryVelocity != 0) {
          startScrollAnimation(details);
        }
        widget.onSnapEnd(widget.stops.indexOf(endStop));
      } else if (isAtMin()) {
        widget.onSnapEnd(widget.stops.indexOf(endStop));
      } else {
        endSnapStopIndex = widget.stops.indexOf(endStop);
        setState(() {
          currentHeight = height * endStop;
        });
      }
    }
  }

  bool isAtMax() {
    return currentHeight >= maxDrawerHeight;
  }

  bool isAtMin() {
    return currentHeight <= minDrawerHeight;
  }

  double calculateScrollDistance(double velocity) {
    var d = 0.99;
    var dCoeff = 1000.0 * (d - 1) / d;
    var destination = _scrollController.offset + velocity / dCoeff;
    return destination;
  }

  // returns time in seconds
  double calculateScrollDuration(double velocity) {
    var d = 0.99;
    var dCoeff = 1000.0 * (d - 1) / d;
    var threshold = 0.1;
    var timeInterval = (log(-dCoeff * threshold / velocity.abs()) / dCoeff);
    return timeInterval;
  }

  // atTime is in milliseconds
  double calculateCurrentScrollValue(double atTime, double startValue, double startVelocity) {
    var d = 0.99;
    var dCoeff = 1000.0 * (d - 1) / d;
    return startValue + (pow(d, atTime) - 1) / dCoeff * startVelocity;
  }

  // triggers scroll animation based on drag velocity after drag end event
  void startScrollAnimation(DragEndDetails details) {
    double duration = calculateScrollDuration(details.primaryVelocity);
    int durationInMilliseconds = (duration * 1000).round();
    startScrollVelocity = details.primaryVelocity;
    scrollStartOffset = _scrollController.offset;

    _animationController.reset();
    _animationController.duration = Duration(milliseconds: durationInMilliseconds);
    _animation?.removeListener(listenToAnimation);
    _animation = Tween<double>(
      begin: 0,
      end: durationInMilliseconds.toDouble(),
    ).animate(_animationController);
    _animationController.forward();
    _animation.addListener(listenToAnimation);
  }

  void listenToAnimation() {
    double currentOffset = calculateCurrentScrollValue(_animation.value, scrollStartOffset, -startScrollVelocity);
    if (_scrollController.position.outOfRange) {
      _animationController.stop();
      return;
    }
    _scrollController.jumpTo(currentOffset);
  }
}
