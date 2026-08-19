import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:flutter_epub_viewer/flutter_epub_viewer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/tts_service.dart';
import '../models/ebook_annotation.dart';
import '../providers/reader_state_provider.dart';

class EbookReaderPage extends ConsumerStatefulWidget {
  final String assetPath;

  const EbookReaderPage({super.key, required this.assetPath});

  @override
  ConsumerState<EbookReaderPage> createState() => _EbookReaderPageState();
}

class _EbookReaderPageState extends ConsumerState<EbookReaderPage>
    with SingleTickerProviderStateMixin {
  late EpubController _controller;
  late EpubSource _epubSource;
  final TtsService _ttsService = TtsService();
  late TabController _drawerTabController;
  EpubMetadata? _bookMetadata;
  String? _initialCfi;
  bool _isInitialCfiLoaded = false;
  double _touchDownX = 0;
  double _touchDownY = 0;
  DateTime _touchDownTime = DateTime.now();

  final ValueNotifier<bool> _isSpeakingNotifier = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _controller = EpubController();
    _epubSource = widget.assetPath.startsWith('/')
        ? EpubSource.fromFile(io.File(widget.assetPath))
        : EpubSource.fromAsset(widget.assetPath);
    _drawerTabController = TabController(length: 3, vsync: this);
    _ttsService.onSpeechStateChanged = (speaking) {
      _isSpeakingNotifier.value = speaking;
    };
    _ttsService.init().catchError((e) {
      debugPrint("Error initializing TTS: $e");
    });
  }

  @override
  void dispose() {
    _drawerTabController.dispose();
    _isSpeakingNotifier.dispose();
    _ttsService.onSpeechStateChanged = null;
    _ttsService.stop();
    super.dispose();
  }

  void _pronounceText(String text) {
    final cleanText = text.trim();
    if (cleanText.isNotEmpty) {
      _ttsService.speak(cleanText);
    }
  }

  // 🔍 SEARCH
  void _openSearch() {
    showDialog(
      context: context,
      builder: (context) {
        final searchController = TextEditingController();

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Search in Book"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: searchController,
                    decoration: const InputDecoration(
                      hintText: "Enter text...",
                      prefixIcon: Icon(Icons.search),
                    ),
                    onSubmitted: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 16),
                  if (searchController.text.isNotEmpty)
                    FutureBuilder<List<EpubSearchResult>>(
                      future: _controller.search(query: searchController.text),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final results = snapshot.data!;
                        if (results.isEmpty) {
                          return const Text("No results found");
                        }

                        return SizedBox(
                          height: 300,
                          width: double.maxFinite,
                          child: ListView.separated(
                            itemCount: results.length,
                            separatorBuilder: (context, index) =>
                                const Divider(),
                            itemBuilder: (context, index) {
                              final item = results[index];

                              return ListTile(
                                title: Text(
                                  item.excerpt.trim(),
                                  style: const TextStyle(fontSize: 14),
                                ),
                                subtitle: Text(
                                  "Tap to view",
                                  style: TextStyle(
                                    color: Colors.blue.shade300,
                                    fontSize: 12,
                                  ),
                                ),
                                onTap: () {
                                  _controller.display(cfi: item.cfi);
                                  _controller.addHighlight(
                                    cfi: item.cfi,
                                    color: Colors.amber,
                                    opacity: 0.5,
                                  );
                                  Navigator.pop(context);
                                },
                              );
                            },
                          ),
                        );
                      },
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Close"),
                ),
                TextButton(
                  onPressed: () => setDialogState(() {}),
                  child: const Text("Search"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ℹ️ BOOK METADATA DIALOG
  Future<void> _showBookInfo() async {
    try {
      _bookMetadata ??= await _controller.getMetadata();
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.deepPurpleAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _bookMetadata?.title ?? "Book Details",
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_bookMetadata?.author != null) ...[
                    const Text(
                      "Author:",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(_bookMetadata!.author!),
                    const SizedBox(height: 12),
                  ],
                  if (_bookMetadata?.publisher != null) ...[
                    const Text(
                      "Publisher:",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(_bookMetadata!.publisher!),
                    const SizedBox(height: 12),
                  ],
                  if (_bookMetadata?.language != null) ...[
                    const Text(
                      "Language:",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(_bookMetadata!.language!),
                    const SizedBox(height: 12),
                  ],
                  if (_bookMetadata?.description != null &&
                      _bookMetadata!.description!.isNotEmpty) ...[
                    const Text(
                      "Description:",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _bookMetadata!.description!,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Close"),
              ),
            ],
          );
        },
      );
    } catch (e) {
      debugPrint("Error fetching metadata: $e");
    }
  }

  // ⚙️ SETTINGS & THEME CUSTOMIZATION
  void _openSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final state = ref.watch(readerStateProvider(widget.assetPath));
            final notifier = ref.read(
              readerStateProvider(widget.assetPath).notifier,
            );

            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: Text(
                      "Reader Customization",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // Auto Read Audio Toggle
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("Auto Read Audio on Selection"),
                    subtitle: const Text(
                      "Automatically speak text when tapped or selected",
                    ),
                    value: state.isTtsEnabled,
                    secondary: Icon(
                      state.isTtsEnabled ? Icons.volume_up : Icons.volume_off,
                      color: state.isTtsEnabled ? Colors.greenAccent : null,
                    ),
                    onChanged: (val) {
                      notifier.toggleTtsEnabled();
                      if (!val) _ttsService.stop();
                    },
                  ),
                  const SizedBox(height: 16),

                  // Theme Presets
                  const Text(
                    "Theme Preset",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: ReaderThemePreset.values.map((preset) {
                      final isSelected = state.themePreset == preset;
                      return ChoiceChip(
                        label: Text(preset.label),
                        selected: isSelected,
                        onSelected: (val) {
                          if (val) notifier.setThemePreset(preset);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Flow Mode Switcher
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Reading Mode",
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      SegmentedButton<EpubFlow>(
                        segments: const [
                          ButtonSegment(
                            value: EpubFlow.paginated,
                            label: Text("Paginated"),
                            icon: Icon(Icons.menu_book),
                          ),
                          ButtonSegment(
                            value: EpubFlow.scrolled,
                            label: Text("Scroll"),
                            icon: Icon(Icons.swap_vert),
                          ),
                        ],
                        selected: {state.flowMode},
                        onSelectionChanged: (set) {
                          if (set.isNotEmpty) {
                            final newFlow = set.first;
                            notifier.setFlowMode(newFlow);
                            _controller.setFlow(flow: newFlow);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Font Size Slider
                  Row(
                    children: [
                      const Icon(Icons.format_size),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Slider(
                          value: state.fontSize,
                          min: 12,
                          max: 32,
                          divisions: 20,
                          label: "${state.fontSize.toInt()} px",
                          onChanged: (val) {
                            notifier.setFontSize(val);
                            _controller.setFontSize(fontSize: val);
                          },
                        ),
                      ),
                      Text("${state.fontSize.toInt()} px"),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Font Family Selector
                  const Text(
                    "Font Family",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  DropdownButton<String>(
                    value: state.fontFamily,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(
                        value: 'system-ui',
                        child: Text("System Default"),
                      ),
                      DropdownMenuItem(
                        value: 'Georgia, serif',
                        child: Text("Georgia (Serif)"),
                      ),
                      DropdownMenuItem(
                        value: 'Arial, sans-serif',
                        child: Text("Arial (Sans-Serif)"),
                      ),
                      DropdownMenuItem(
                        value: 'Courier New, monospace',
                        child: Text("Courier (Monospace)"),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        notifier.setFontFamily(val);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // 🎨 HIGHLIGHT CREATION MODAL
  void _addHighlightDialog(EpubTextSelection selection) {
    String selectedColor = "FFFF00"; // Default Yellow
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Add Highlight & Note"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '"${selection.selectedText.trim()}"',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontStyle: FontStyle.italic,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Color:",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _colorBubble(
                        "FFFF00",
                        Colors.yellow,
                        selectedColor,
                        () => setDialogState(() => selectedColor = "FFFF00"),
                      ),
                      _colorBubble(
                        "00FF00",
                        Colors.green,
                        selectedColor,
                        () => setDialogState(() => selectedColor = "00FF00"),
                      ),
                      _colorBubble(
                        "00BFFF",
                        Colors.lightBlue,
                        selectedColor,
                        () => setDialogState(() => selectedColor = "00BFFF"),
                      ),
                      _colorBubble(
                        "FF69B4",
                        Colors.pinkAccent,
                        selectedColor,
                        () => setDialogState(() => selectedColor = "FF69B4"),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(
                      hintText: "Add note (optional)...",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () {
                    final color = Color(int.parse("0xFF$selectedColor"));
                    _controller.addHighlight(
                      cfi: selection.selectionCfi,
                      color: color,
                      opacity: 0.4,
                    );

                    final highlightItem = HighlightItem(
                      cfi: selection.selectionCfi,
                      text: selection.selectedText,
                      colorHex: selectedColor,
                      note: noteController.text.trim().isEmpty
                          ? null
                          : noteController.text.trim(),
                      createdAt: DateTime.now(),
                    );

                    ref
                        .read(readerStateProvider(widget.assetPath).notifier)
                        .addHighlight(highlightItem);

                    _controller.clearSelection();
                    Navigator.pop(context);
                  },
                  child: const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _colorBubble(
    String hex,
    Color color,
    String selectedHex,
    VoidCallback onTap,
  ) {
    final isSelected = hex == selectedHex;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
          boxShadow: isSelected
              ? [const BoxShadow(color: Colors.black45, blurRadius: 4)]
              : null,
        ),
      ),
    );
  }

  // 🔊 READ ENTIRE CURRENT PAGE
  Future<void> _readCurrentPage() async {
    final isTtsOn = ref
        .read(readerStateProvider(widget.assetPath))
        .isTtsEnabled;

    if (!isTtsOn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Audio is turned OFF. Turn ON audio from top bar to read page.",
          ),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_ttsService.isSpeaking) {
      await _ttsService.stop();
      return;
    }

    try {
      await _ttsService.stop();
      final currentCfi = ref
          .read(readerStateProvider(widget.assetPath))
          .currentCfi;

      EpubTextExtractRes res;
      if (currentCfi?.startCfi != null && currentCfi?.endCfi != null) {
        res = await _controller.extractText(
          startCfi: currentCfi!.startCfi,
          endCfi: currentCfi.endCfi,
        );
      } else {
        res = await _controller.extractCurrentPageText();
      }

      final pageText = (res.text ?? "").trim();
      if (!mounted) return;

      if (pageText.isNotEmpty) {
        _pronounceText(pageText);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("No readable text found on current page."),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error reading current page text: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialCfiLoaded) {
      _initialCfi = ref
          .read(readerStateProvider(widget.assetPath))
          .currentCfi
          ?.startCfi;
      _isInitialCfiLoaded = true;
    }

    final presetTheme = ref.watch(
      readerStateProvider(widget.assetPath).select((s) => s.themePreset),
    );
    final scaffoldBg = Color(
      int.parse(presetTheme.bgColor.replaceFirst('#', '0xFF')),
    );

    return Scaffold(
      backgroundColor: scaffoldBg,
      // 📖 ISOLATED DRAWER
      drawer: Drawer(
        child: Consumer(
          builder: (context, ref, _) {
            final state = ref.watch(
              readerStateProvider(widget.assetPath).select(
                (s) =>
                    (s.chapters, s.bookmarks, s.highlights, s.safeTotalPages),
              ),
            );

            final chapters = state.$1;
            final bookmarks = state.$2;
            final highlights = state.$3;
            final safeTotalPages = state.$4;
            final notifier = ref.read(
              readerStateProvider(widget.assetPath).notifier,
            );

            return Column(
              children: [
                UserAccountsDrawerHeader(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                  ),
                  accountName: Text(
                    _bookMetadata?.title ?? "E-Book Library",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  accountEmail: Text(
                    _bookMetadata?.author ?? "Audiobook Library Reader",
                    style: const TextStyle(fontSize: 13),
                  ),
                  currentAccountPicture: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: const Icon(
                      Icons.book,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
                TabBar(
                  controller: _drawerTabController,
                  tabs: const [
                    Tab(icon: Icon(Icons.list), text: "Chapters"),
                    Tab(icon: Icon(Icons.bookmark), text: "Bookmarks"),
                    Tab(icon: Icon(Icons.highlight), text: "Highlights"),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _drawerTabController,
                    children: [
                      // 1️⃣ CHAPTERS TAB
                      chapters.isEmpty
                          ? const Center(child: Text("Loading chapters..."))
                          : ListView.builder(
                              itemCount: chapters.length,
                              itemBuilder: (context, index) {
                                final chapter = chapters[index];
                                return ListTile(
                                  title: Text(chapter.title),
                                  onTap: () {
                                    _controller.display(cfi: chapter.href);
                                    notifier.setChapterTitle(chapter.title);
                                    Navigator.pop(context);
                                  },
                                );
                              },
                            ),

                      // 2️⃣ BOOKMARKS TAB
                      bookmarks.isEmpty
                          ? const Center(child: Text("No bookmarks added yet."))
                          : ListView.builder(
                              itemCount: bookmarks.length,
                              itemBuilder: (context, index) {
                                final item = bookmarks[index];
                                return ListTile(
                                  leading: const Icon(
                                    Icons.bookmark,
                                    color: Colors.amber,
                                  ),
                                  title: Text(item.title),
                                  subtitle: Text(
                                    "Page ${(item.percentage * safeTotalPages).round().clamp(1, safeTotalPages)} of $safeTotalPages • ${item.createdAt.hour}:${item.createdAt.minute.toString().padLeft(2, '0')}",
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 20,
                                    ),
                                    onPressed: () =>
                                        notifier.removeBookmark(item),
                                  ),
                                  onTap: () {
                                    _controller.display(cfi: item.cfi);
                                    Navigator.pop(context);
                                  },
                                );
                              },
                            ),

                      // 3️⃣ HIGHLIGHTS TAB
                      highlights.isEmpty
                          ? const Center(
                              child: Text("No highlights saved yet."),
                            )
                          : ListView.builder(
                              itemCount: highlights.length,
                              itemBuilder: (context, index) {
                                final item = highlights[index];
                                final hColor = Color(
                                  int.parse("0xFF${item.colorHex}"),
                                );
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: hColor,
                                    radius: 8,
                                  ),
                                  title: Text(
                                    item.text,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  subtitle: item.note != null
                                      ? Text(
                                          "Note: ${item.note}",
                                          style: const TextStyle(
                                            fontStyle: FontStyle.italic,
                                          ),
                                        )
                                      : null,
                                  trailing: IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      _controller.removeHighlight(
                                        cfi: item.cfi,
                                      );
                                      notifier.removeHighlight(item);
                                    },
                                  ),
                                  onTap: () {
                                    _controller.display(cfi: item.cfi);
                                    Navigator.pop(context);
                                  },
                                );
                              },
                            ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),

      body: Stack(
        children: [
          // 📄 1. EPUB VIEWPORT: PERMANENT FULL SCREEN FRAME (NEVER RESIZES)
          Consumer(
            builder: (context, ref, _) {
              final typography = ref.watch(
                readerStateProvider(widget.assetPath).select(
                  (s) => (s.fontSize, s.fontFamily, s.themePreset, s.flowMode),
                ),
              );

              final fSize = typography.$1;
              final fFamily = typography.$2;
              final preset = typography.$3;
              final flow = typography.$4;

              final notifier = ref.read(
                readerStateProvider(widget.assetPath).notifier,
              );

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 25.0),
                child: EpubViewer(
                  key: ValueKey('$fSize-$fFamily-${preset.name}-${flow.name}'),
                  epubController: _controller,
                  epubSource: _epubSource,
                  suppressNativeContextMenu: true,
                  initialCfi: _initialCfi,
                  onTouchDown: (x, y) {
                    _touchDownX = x;
                    _touchDownY = y;
                    _touchDownTime = DateTime.now();
                  },
                  onTouchUp: (x, y) {
                    final dx = (x - _touchDownX).abs();
                    final dy = (y - _touchDownY).abs();
                    final dt = DateTime.now()
                        .difference(_touchDownTime)
                        .inMilliseconds;

                    // Only toggle controls on quick tap (distance < 0.08 and duration < 400ms)
                    // Swiping/scrolling gestures (distance >= 0.08) will NOT trigger controls toggle
                    if (dx < 0.08 && dy < 0.08 && dt < 400) {
                      if (y >= 0.15 && y <= 0.85) {
                        notifier.toggleControls();
                      }
                    }
                  },
                  displaySettings: EpubDisplaySettings(
                    flow: flow,
                    snap: flow == EpubFlow.paginated,
                    fontSize: fSize.toInt(),
                    theme: EpubTheme.custom(
                      customCss: {
                        'body': {
                          'background-color': preset.bgColor,
                          'color': preset.textColor,
                          'font-family': fFamily,
                          'font-size': '${fSize}px',
                          'line-height': '1.5',
                          'padding-top': '40px !important',
                          'padding-bottom': '48px !important',
                          'padding-left': '20px !important',
                          'padding-right': '20px !important',
                          'box-sizing': 'border-box !important',
                        },
                        'p, div, span, h1, h2, h3, h4, h5, h6, li, td, a': {
                          'font-family': fFamily,
                          'font-size': '${fSize}px',
                          'color': preset.textColor,
                          'line-height': '1.5',
                        },
                        '*': {
                          '-webkit-tap-highlight-color': 'transparent',
                          'outline': 'none',
                        },
                        '::selection': {
                          'background-color': '#b3d4fc',
                          'color': '#000000',
                        },
                      },
                    ),
                  ),
                  onRelocated: (cfi) {
                    notifier.saveProgress(cfi);
                    if (_ttsService.isSpeaking) {
                      _ttsService.stop();
                    }
                  },
                  onChaptersLoaded: (chapters) {
                    notifier.setChapters(chapters);
                  },
                  onTextSelected: (selection) {
                    notifier.setSelection(selection);
                    final isTtsOn = ref
                        .read(readerStateProvider(widget.assetPath))
                        .isTtsEnabled;
                    final text = selection.selectedText.trim();
                    if (isTtsOn && text.isNotEmpty) {
                      _pronounceText(text);
                    }
                  },
                ),
              );
            },
          ),
          // 🔝 2. ISOLATED TOP CONTROL BAR OVERLAY (Zero height shifts)
          Consumer(
            builder: (context, ref, _) {
              final controlsData = ref.watch(
                readerStateProvider(widget.assetPath).select(
                  (s) => (
                    s.showControls,
                    s.isTtsEnabled,
                    s.isDarkMode,
                    s.currentChapterTitle,
                  ),
                ),
              );

              final showControls = controlsData.$1;
              final isTtsEnabled = controlsData.$2;
              final isDarkMode = controlsData.$3;
              final currentChapterTitle = controlsData.$4;

              if (!showControls) return const SizedBox.shrink();

              final notifier = ref.read(
                readerStateProvider(widget.assetPath).notifier,
              );

              return Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Material(
                  elevation: 6,
                  color: const Color(0xFA121212),
                  child: SafeArea(
                    bottom: false,
                    child: Container(
                      height: kToolbarHeight,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        children: [
                          Builder(
                            builder: (innerContext) => IconButton(
                              icon: const Icon(Icons.menu, color: Colors.white),
                              onPressed: () =>
                                  Scaffold.of(innerContext).openDrawer(),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              currentChapterTitle.isNotEmpty
                                  ? currentChapterTitle
                                  : "Ebook Reader",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              isTtsEnabled ? Icons.volume_up : Icons.volume_off,
                              color: isTtsEnabled
                                  ? Colors.lightGreenAccent
                                  : Colors.white70,
                            ),
                            tooltip: isTtsEnabled
                                ? "Auto Audio Read: ON"
                                : "Auto Audio Read: OFF",
                            onPressed: () {
                              notifier.toggleTtsEnabled();
                              if (isTtsEnabled) {
                                _ttsService.stop();
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    !isTtsEnabled
                                        ? "Auto Audio Read ON: Tap text to hear audio."
                                        : "Auto Audio Read OFF: Tap text will not play audio.",
                                  ),
                                  duration: const Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.bookmark_add_outlined,
                              color: Colors.white,
                            ),
                            tooltip: "Bookmark Page",
                            onPressed: () {
                              final currentCfi = ref
                                  .read(readerStateProvider(widget.assetPath))
                                  .currentCfi;
                              if (currentCfi != null) {
                                notifier.addBookmark(
                                  currentCfi.startCfi,
                                  currentChapterTitle,
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "Page bookmarked successfully!",
                                    ),
                                    duration: Duration(seconds: 2),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(
                              Icons.more_vert,
                              color: Colors.white,
                            ),
                            color: const Color(0xFF2C2C2C),
                            onSelected: (val) {
                              switch (val) {
                                case 'mode':
                                  notifier.toggleTheme();
                                  break;
                                case 'search':
                                  _openSearch();
                                  break;
                                case 'info':
                                  _showBookInfo();
                                  break;
                                case 'settings':
                                  _openSettings();
                                  break;
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'mode',
                                child: Row(
                                  children: [
                                    Icon(
                                      isDarkMode
                                          ? Icons.light_mode
                                          : Icons.dark_mode,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      isDarkMode ? "Light Mode" : "Dark Mode",
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'search',
                                child: Row(
                                  children: [
                                    Icon(Icons.search, color: Colors.white),
                                    SizedBox(width: 12),
                                    Text(
                                      "Search in Book",
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'info',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      color: Colors.white,
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      "Book Info",
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'settings',
                                child: Row(
                                  children: [
                                    Icon(Icons.settings, color: Colors.white),
                                    SizedBox(width: 12),
                                    Text(
                                      "Reader Settings",
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // 🎛️ 3. ISOLATED BOTTOM CONTROLS & SCRUBBER BAR OVERLAY
          Consumer(
            builder: (context, ref, _) {
              final controlsData = ref.watch(
                readerStateProvider(widget.assetPath).select(
                  (s) => (
                    s.showControls,
                    s.readingProgress,
                    s.currentPage,
                    s.safeTotalPages,
                    s.currentChapterTitle,
                  ),
                ),
              );

              final showControls = controlsData.$1;
              final readingProgress = controlsData.$2;
              final currentPage = controlsData.$3;
              final safeTotalPages = controlsData.$4;
              final currentChapterTitle = controlsData.$5;

              if (!showControls) return const SizedBox.shrink();

              return Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  color: Colors.black.withValues(alpha: 0.88),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            "Page $currentPage",
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Expanded(
                            child: Slider(
                              value: readingProgress.clamp(0.0, 1.0),
                              min: 0.0,
                              max: 1.0,
                              activeColor: Colors.deepPurpleAccent,
                              onChanged: (val) {
                                _controller.toProgressPercentage(val);
                              },
                            ),
                          ),
                          Text(
                            "Page $safeTotalPages",
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.chevron_left,
                              color: Colors.white,
                            ),
                            onPressed: () => _controller.prev(),
                          ),
                          Expanded(
                            child: Text(
                              currentChapterTitle.isNotEmpty
                                  ? currentChapterTitle
                                  : "Reading...",
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.chevron_right,
                              color: Colors.white,
                            ),
                            onPressed: () => _controller.next(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),

      // 🔊 ISOLATED FLOATING ACTION BUTTONS
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Consumer(
        builder: (context, ref, _) {
          final fabData = ref.watch(
            readerStateProvider(
              widget.assetPath,
            ).select((s) => (s.showControls, s.lastSelection)),
          );

          final showControls = fabData.$1;
          final lastSelection = fabData.$2;

          return Padding(
            padding: EdgeInsets.only(bottom: showControls ? 80.0 : 0.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (lastSelection != null &&
                    lastSelection.selectedText.trim().isNotEmpty) ...[
                  FloatingActionButton.small(
                    heroTag: 'highlight_fab',
                    elevation: 4,
                    backgroundColor: Colors.amber.shade700,
                    foregroundColor: Colors.white,
                    onPressed: () => _addHighlightDialog(lastSelection),
                    child: const Icon(Icons.format_quote, size: 20),
                  ),
                  const SizedBox(height: 8),
                ],
                ValueListenableBuilder<bool>(
                  valueListenable: _isSpeakingNotifier,
                  builder: (context, isSpeaking, _) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FloatingActionButton.small(
                          heroTag: 'read_page_fab',
                          elevation: 4,
                          backgroundColor: isSpeaking
                              ? Colors.orange.shade800
                              : Colors.teal,
                          foregroundColor: Colors.white,
                          tooltip: isSpeaking
                              ? "Stop Reading Page"
                              : "Read Entire Page",
                          onPressed: _readCurrentPage,
                          child: Icon(
                            isSpeaking
                                ? Icons.stop_rounded
                                : Icons.chrome_reader_mode,
                            size: 20,
                          ),
                        ),
                        const SizedBox(height: 8),
                        FloatingActionButton.small(
                          heroTag: 'tts_small_fab',
                          elevation: 6,
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          onPressed: () {
                            final isTtsOn = ref
                                .read(readerStateProvider(widget.assetPath))
                                .isTtsEnabled;
                            if (!isTtsOn) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "Audio is turned OFF. Turn ON audio from top bar to read.",
                                  ),
                                  duration: Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              return;
                            }
                            if (_ttsService.isSpeaking) {
                              _ttsService.pause();
                            } else if (lastSelection != null &&
                                lastSelection.selectedText.trim().isNotEmpty) {
                              _pronounceText(lastSelection.selectedText);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "Select text or tap page reader to listen.",
                                  ),
                                  duration: Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                          child: Icon(
                            isSpeaking
                                ? Icons.pause_rounded
                                : _ttsService.isPaused
                                ? Icons.play_arrow_rounded
                                : Icons.volume_up_rounded,
                            size: 20,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
