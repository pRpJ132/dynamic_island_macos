import 'dart:async';

import 'package:dynamic_lake_macos/controller/main_app_controller.dart';
import 'package:dynamic_lake_macos/service/browser_service.dart';
import 'package:dynamic_lake_macos/service/search_history_service.dart';
import 'package:dynamic_lake_macos/service/search_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class DynamicIslandSearch extends StatefulWidget {
  const DynamicIslandSearch({
    super.key,
    this.searchService,
    this.historyService,
    this.browserService,
  });

  final SearchService? searchService;
  final SearchHistoryService? historyService;
  final BrowserService? browserService;

  @override
  State<DynamicIslandSearch> createState() => _DynamicIslandSearchState();
}

class _DynamicIslandSearchState extends State<DynamicIslandSearch>
    with TickerProviderStateMixin {
  late final SearchService _searchService;
  late final SearchHistoryService _historyService;
  late final BrowserService _browserService;

  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<String> _history = [];
  List<String> _suggestions = [];
  List<BrowserOption> _browsers = [];

  Timer? _debounce;

  bool _showHistory = true;
  bool _loadingSuggestions = false;

  String _browserName = '';

  @override
  void initState() {
    super.initState();

    _searchService = widget.searchService ?? SearchService();
    _historyService = widget.historyService ?? SearchHistoryService();
    _browserService = widget.browserService ?? BrowserService();

    _textController.addListener(_onTextChanged);

    _loadInitialData();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  Future<void> _loadInitialData() async {
    try {
      final results = await Future.wait([
        _historyService.getHistory(),
        _browserService.discoverBrowsers(),
      ]);

      if (!mounted) return;

      final history = results[0] as List<String>;
      final browsers = results[1] as List<BrowserOption>;

      String browserName = '';

      if (!mounted) return;
      final String? selectedBrowser = await _browserService.getSaveBrowser();
      if (selectedBrowser != null) {
        browserName = selectedBrowser;
      } else {
        if (browsers.any((b) => b.name == 'Safari')) {
          browserName = 'Safari';
        } else if (browsers.any((b) => b.name == 'Google Chrome')) {
          browserName = 'Google Chrome';
        } else if (browsers.isNotEmpty) {
          browserName = browsers.first.name;
        }
      }

      setState(() {
        _history = history;
        _browsers = browsers;
        _browserName = browserName;
      });
    } catch (error) {
      debugPrint('Search initialization failed: $error');
    }
  }

  void _onTextChanged() {
    final query = _textController.text.trim();

    _debounce?.cancel();

    if (query.isEmpty) {
      setState(() {
        _suggestions = [];
        _showHistory = true;
        _loadingSuggestions = false;
      });
      return;
    }

    setState(() {
      _showHistory = true;
      _loadingSuggestions = true;
    });

    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final suggestions = await _searchService.suggestions(query);

        if (!mounted || _textController.text.trim() != query) {
          return;
        }

        if (suggestions.isNotEmpty) {
          setState(() {
            _suggestions = suggestions;
            _showHistory = false;
            _loadingSuggestions = false;
          });
        } else {
          final history = await _historyService.getHistory();

          if (!mounted || _textController.text.trim() != query) {
            return;
          }

          setState(() {
            _history = history;
            _suggestions = [];
            _showHistory = true;
            _loadingSuggestions = false;
          });
        }
      } catch (error) {
        if (!mounted || _textController.text.trim() != query) {
          return;
        }

        setState(() {
          _suggestions = [];
          _showHistory = true;
          _loadingSuggestions = false;
        });

        debugPrint('Search suggestions failed: $error');
      }
    });
  }

  Future<void> _submit(String value) async {
    final query = value.trim();

    if (query.isEmpty) return;

    _debounce?.cancel();

    try {
      await _historyService.addQuery(query);

      if (!mounted) return;

      setState(() {
        _history = [
          query,
          ..._history.where(
            (item) => item.toLowerCase() != query.toLowerCase(),
          ),
        ];

        _textController.text = query;
        _textController.selection = TextSelection.collapsed(
          offset: query.length,
        );

        _showHistory = true;
        _suggestions = [];
      });

      await _openSearch(query);
    } catch (error) {
      debugPrint('Unable to submit search: $error');
    }
  }

  Future<void> _openSearch(String query) async {
    try {
      await _browserService.openSearch(
        query,
        browserName: _browserName.isEmpty ? null : _browserName,
      );

      if (!mounted) return;

      final history = await _historyService.getHistory();

      if (!mounted) return;

      setState(() {
        _history = history;
      });
    } catch (error) {
      debugPrint('Unable to open browser: $error');
    }
  }

  Widget _buildDropdown<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    required MainAppController mappc,
    double maxWidth = 125,
  }) {
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      height: 32,
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 183, 183, 183).withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          isExpanded: true,
          borderRadius: BorderRadius.circular(12),
          padding: EdgeInsets.symmetric(horizontal: 12),
          menuMaxHeight: 280,
          dropdownColor: mappc.isDynamicIsland ? const Color.fromARGB(255, 14, 14, 14) : const Color.fromARGB(237, 67, 66, 66),
          elevation: 8,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 17,
            color: Color(0xFFB8BAC4),
          ),
          style: const TextStyle(
            color: Color(0xFFE7E8ED),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
          selectedItemBuilder: (context) {
            return items.map((item) {
              return Align(
                alignment: Alignment.centerLeft,
                child: DefaultTextStyle(
                  style: const TextStyle(
                    color: Color(0xFFE7E8ED),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  child: item.child,
                ),
              );
            }).toList();
          },
          items: items.map((item) {
            return DropdownMenuItem<T>(
              value: item.value,
              enabled: item.enabled,
              alignment: Alignment.centerLeft,
              child: DefaultTextStyle(
                style: const TextStyle(
                  color: Color(0xFFE7E8ED),
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                child: item.child,
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildToolbar(
    MainAppController mappc
  ) {
    final browserItems = _browsers.map((browser) {
      return DropdownMenuItem<String>(
        value: browser.name,
        child: Text(browser.name),
      );
    }).toList();

    return Row(
      children: [
        Icon(
          _showHistory ? Icons.history_rounded : Icons.auto_awesome,
          size: 16,
          color: Colors.grey,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            _showHistory ? 'История поиска' : 'Подсказки',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        if (_browsers.isNotEmpty) ...[
          const SizedBox(width: 7),
          _buildDropdown<String>(
            value: _browsers.any((b) => b.name == _browserName)
                ? _browserName
                : _browsers.first.name,
            maxWidth: 135,
            items: browserItems,
            onChanged: (value) {
              if (value != null) {
                _browserService.selectBrowser(value);
                setState(() => _browserName = value);
              }
            },
            mappc: mappc
          ),
        ],
      ],
    );
  }

  Widget _buildSearchField() {
    return Row(
      children: [
        const Icon(
          Icons.search_rounded,
          size: 20,
          color: Color(0xFFB5B8C5),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextSelectionTheme(
            data: const TextSelectionThemeData(
              selectionColor: Color.fromARGB(105, 255, 228, 146), 
            ),
            child: TextField(
              controller: _textController,
              focusNode: _focusNode,
              style: const TextStyle(
                color: Color(0xFFF3F3F6),
                fontSize: 14,
              ),
              cursorColor: const Color.fromARGB(255, 255, 255, 255),
              textInputAction: TextInputAction.search,
              onSubmitted: _submit,
              decoration: const InputDecoration(
                hintText: 'Поиск в интернете',
                hintStyle: TextStyle(
                  color: Color(0xFF777B89),
                  fontSize: 14,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
        if (_textController.text.isNotEmpty) ...[
          SizedBox(width: 2),
          GestureDetector(
            onTap: () {
              _textController.clear();
              _focusNode.requestFocus();
            },
            child: const Icon(
              Icons.close_rounded,
              color: Color(0xFF858997),
              size: 17,
            ),
          ),
        ]
      ],
    );
  }

  Widget _buildEntries(List<String> entries) {
    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _showHistory
                    ? Icons.manage_search_rounded
                    : Icons.search_off_rounded,
                color: Colors.white.withValues(alpha: 0.25),
                size: 23,
              ),
              const SizedBox(height: 7),
              Text(
                _loadingSuggestions
                    ? 'Поиск подсказок…'
                    : _showHistory
                        ? 'История пока пуста'
                        : 'Подсказок нет',
                style: const TextStyle(
                  color: Color(0xFF858997),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 180),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.only(top: 5, bottom: 4),
        itemCount: entries.length,
        separatorBuilder: (_, _) => const SizedBox(height: 2),
        itemBuilder: (context, index) {
          final item = entries[index];

          return Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              borderRadius: BorderRadius.circular(9),
              hoverColor: Colors.white.withValues(alpha: 0.055),
              onTap: () {
                _textController.value = TextEditingValue(
                  text: item,
                  selection: TextSelection.collapsed(
                    offset: item.length,
                  ),
                );

                _submit(item);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 9,
                ),
                child: Row(
                  children: [
                    Icon(
                      _showHistory
                          ? Icons.history_rounded
                          : Icons.search_rounded,
                      color: const Color(0xFF9295A2),
                      size: 17,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFE4E5EA),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.north_west_rounded,
                      color: Color(0xFF777B89),
                      size: 13,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();

    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _focusNode.dispose();

    if (widget.searchService == null) {
      _searchService.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entries = _showHistory ? _history : _suggestions;

    return Consumer<MainAppController>(
      builder: (context, controller, child) {
        return Padding(
          padding: EdgeInsets.only(
            top: controller.isDynamicIsland ? 36 : controller.isExpanded ? 20 : 0,
          ),
          child: Align(
            alignment: controller.isDynamicIsland ? AlignmentGeometry.topCenter : controller.isExpanded ? AlignmentGeometry.topCenter : AlignmentGeometry.center,
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSearchField(),
                            
                  Align(
                    alignment: Alignment.topCenter,
                    child: controller.isExpanded
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Padding(
                                padding: EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                child: Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: Color(0x1FFFFFFF),
                                ),
                              ),
                              _buildToolbar(controller),
                              const SizedBox(height: 5),
                              _buildEntries(entries),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}