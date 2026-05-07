import 'dart:io';
import 'dart:typed_data';
import 'package:dynamic_lake_macos/service/app_service.dart';
import 'package:dynamic_lake_macos/view/dynamic_island_app_open/service/icon_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dynamic_lake_macos/controller/main_app_controller.dart';

class DynamicIslandAppOpen extends StatefulWidget {
  const DynamicIslandAppOpen({super.key});

  @override
  State<DynamicIslandAppOpen> createState() => _DynamicIslandAppOpenState();
}

class _DynamicIslandAppOpenState extends State<DynamicIslandAppOpen> {
  final ScrollController _scrollController = ScrollController();
  late final appService = context.read<AppService>();

  static const double _itemWidth = 40.0;
  static const double _itemSpacing = 10.0;
  static const double _itemStep = _itemWidth + _itemSpacing;

  static const int _visibleCount = 6;
  static const int _scrollStep = 3;

  int _pageOffset = 0;
  int get _maxPageOffset => appService.apps.length - _visibleCount;

  void _moveLeft() {
    if (_pageOffset <= 0) return;
    setState(() {
      _pageOffset = (_pageOffset - _scrollStep).clamp(0, _maxPageOffset);
    });
    _animateScroll();
  }

  void _moveRight() {
    if (_pageOffset >= _maxPageOffset) return;
    setState(() {
      _pageOffset = (_pageOffset + _scrollStep).clamp(0, _maxPageOffset);
    });
    _animateScroll();
  }

  void _animateScroll() {
    _scrollController.animateTo(
      _pageOffset * _itemStep,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  bool get _canGoLeft  => _pageOffset > 0;
  bool get _canGoRight => _pageOffset < _maxPageOffset;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String getAppName(String path) {
    return path.split('/').last.replaceAll('.app', '');
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MainAppController>(
      builder: (_, mainAppController, _) {
        final isExpanded = mainAppController.stateApp == IslandState.expanded;
        return AnimatedPadding(
          padding: EdgeInsetsGeometry.only(bottom: isExpanded ? 0 : 10), 
          duration: Duration(milliseconds: 500),
          curve: Curves.decelerate,
          child: Stack(
            children: [
              AnimatedAlign(
                alignment: isExpanded ? .center : .bottomCenter,
                duration: Duration(milliseconds: 500),
                curve: Curves.decelerate,
                child: Consumer<AppService>(
                  builder: (context, appServiceValue, child) {
                    final apps = appServiceValue.apps;
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: _canGoLeft ? _moveLeft : () {},
                          icon: Icon(
                            Icons.arrow_back_ios,
                            size: 16,
                            color: _canGoLeft ? Colors.white : const Color.fromARGB(255, 47, 47, 47),
                          ),
                        ),
                                      
                        AnimatedContainer(
                          height: isExpanded ? _itemWidth + 50 : _itemWidth,
                          width: 290,
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeOut,
                          child: ListView.builder(
                              physics: const NeverScrollableScrollPhysics(),
                              controller: _scrollController,
                              scrollDirection: Axis.horizontal,
                              itemCount: apps.length,
                              itemBuilder: (context, index) {
                                final appPath = apps[index];
                                final appName = getAppName(appPath);
                                return GestureDetector(
                                  onTap: () => Process.run('open', [appPath]),
                                  onSecondaryTap: () {
                                    appServiceValue.removeApp(appPath);
                                  },
                                  child: AnimatedContainer(
                                    height: _itemWidth,
                                    width: _itemWidth,
                                    margin: EdgeInsets.only(
                                      right: index != apps.length - 1 ? _itemSpacing : 0,
                                    ),
                                    duration: const Duration(milliseconds: 200),
                                    child: Column(
                                      mainAxisAlignment: .center,
                                      children: [
                                        _AppIcon(appPath: appPath),
                                        Flexible(
                                          child: AnimatedOpacity(
                                            duration: Duration(milliseconds: 150),
                                            curve: Curves.easeIn,
                                            opacity: isExpanded ? 1 : 0,
                                            child: Text(
                                              textAlign: TextAlign.center,
                                              appName,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(color: Colors.white, fontSize: 8),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            )
                          ),
                          
                          IconButton(
                            onPressed: _canGoRight ? _moveRight : () {},
                            icon: Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: _canGoRight ? Colors.white : const Color.fromARGB(255, 47, 47, 47),
                            ),
                          ),
                        ],
                      );
                    }
                ),
              ),
              AnimatedPadding(
                duration: Duration(milliseconds: 700),
                curve: Curves.decelerate,
                padding: EdgeInsetsGeometry.only(top: isExpanded ? 120 : 70) ,
                child: AnimatedAlign(
                  alignment: isExpanded ? .center : .bottomCenter,
                  duration: Duration(milliseconds: 700),
                  curve: Curves.decelerate,
                  child: AnimatedOpacity(
                    duration: Duration(milliseconds: 150),
                    curve: Curves.easeIn,
                    opacity: isExpanded ? 1 : 0,
                    child: TextButton(
                      onPressed: () {}, 
                      child: Text(
                        "Добавить приложение",
                        style: TextStyle(
                          color: Colors.white
                        ),
                      )
                    ),
                  ),
                ),
              )
            ],
          ),
        );
      },
    );
  }
}

class _AppIcon extends StatefulWidget {
  final String appPath;
  const _AppIcon({required this.appPath});

  @override
  State<_AppIcon> createState() => _AppIconState();
}

class _AppIconState extends State<_AppIcon> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: IconRepository().getIcon(widget.appPath),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          return Image.memory(
            snapshot.data!,
            width: 40,
            height: 40,
            gaplessPlayback: true,
          );
        }
        return const Icon(Icons.apps, color: Colors.white, size: 20);
      },
    );
  }
}