import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_epub_viewer/flutter_epub_viewer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/tts_service.dart';
import '../providers/reader_state_provider.dart';

class EbookReaderPage extends ConsumerStatefulWidget {
  final String assetPath;

  const EbookReaderPage({super.key, required this.assetPath});

  @override
  ConsumerState<EbookReaderPage> createState() => _EbookReaderPageState();
}

class _EbookReaderPageState extends ConsumerState<EbookReaderPage> {
  late EpubController _controller;
  final TtsService _ttsService = TtsService();

  @override
  void initState() {
    super.initState();
    _controller = EpubController();
    _ttsService.onSpeechStateChanged = (speaking) {
      if (mounted) {
        setState(() {});
      }
    };
    _ttsService.init().catchError((e) {
      debugPrint("Error initializing TTS: $e");
    });
  }

  @override
  void dispose() {
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
                                    color: Colors.blue.shade700,
                                    fontSize: 12,
                                  ),
                                ),
                                onTap: () {
                                  // Jump to location
                                  _controller.display(cfi: item.cfi);
                                  // Highlight the result in the book
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

  // ⚙️ SETTINGS
  void _openSettings() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final state = ref.watch(readerStateProvider(widget.assetPath));

            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Reader Settings",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),

                  // Font Size
                  Row(
                    children: [
                      const Icon(Icons.text_fields),
                      Expanded(
                        child: Slider(
                          value: state.fontSize,
                          min: 12,
                          max: 32,
                          onChanged: (val) {
                            ref
                                .read(
                                  readerStateProvider(
                                    widget.assetPath,
                                  ).notifier,
                                )
                                .setFontSize(val);
                          },
                        ),
                      ),
                      Text("${state.fontSize.toInt()}"),
                    ],
                  ),

                  // Font Family
                  DropdownButton<String>(
                    value: state.fontFamily,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(
                        value: 'system-ui',
                        child: Text("System"),
                      ),
                      DropdownMenuItem(
                        value: 'Georgia, serif',
                        child: Text("Georgia"),
                      ),
                      DropdownMenuItem(
                        value: 'Arial, sans-serif',
                        child: Text("Arial"),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        ref
                            .read(
                              readerStateProvider(widget.assetPath).notifier,
                            )
                            .setFontFamily(val);
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(readerStateProvider(widget.assetPath));
    final notifier = ref.read(readerStateProvider(widget.assetPath).notifier);

    return Scaffold(
      appBar: state.showControls
          ? AppBar(
              title: const Text("Ebook Reader"),
              actions: [
                IconButton(
                  icon: Icon(
                    state.isDarkMode ? Icons.light_mode : Icons.dark_mode,
                  ),
                  onPressed: () => notifier.toggleTheme(),
                ),
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _openSearch,
                ),
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: _openSettings,
                ),
              ],
            )
          : null,
      drawer: Drawer(
        child: state.chapters.isEmpty
            ? const Center(child: Text("Loading..."))
            : ListView.builder(
                itemCount: state.chapters.length,
                itemBuilder: (context, index) {
                  final chapter = state.chapters[index];

                  return ListTile(
                    title: Text(chapter.title),
                    onTap: () {
                      _controller.display(cfi: chapter.href);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
      ),
      body: Stack(
        children: [
          Consumer(
            builder: (context, ref, _) {
              final typography = ref.watch(
                readerStateProvider(
                  widget.assetPath,
                ).select((s) => (s.fontSize, s.fontFamily, s.isDarkMode)),
              );

              final fSize = typography.$1;
              final fFamily = typography.$2;
              final dark = typography.$3;

              return GestureDetector(
                onTap: () => notifier.toggleControls(),
                child: EpubViewer(
                  key: ValueKey('$fSize-$fFamily-$dark'),
                  epubController: _controller,
                  epubSource: widget.assetPath.startsWith('/')
                      ? EpubSource.fromFile(File(widget.assetPath))
                      : EpubSource.fromAsset(widget.assetPath),
                  initialCfi: state.currentCfi?.startCfi,
                  displaySettings: EpubDisplaySettings(
                    flow: EpubFlow.paginated,
                    snap: true,
                    theme: EpubTheme.custom(
                      customCss: {
                        'body': {
                          'font-family': fFamily,
                          'font-size': '${fSize}px',
                          'background-color':
                              '${dark ? '#121212' : '#ffffff'} !important',
                          'color': '${dark ? '#ffffff' : '#000000'} !important',
                          // 🛠️ Disable tap highlights aggressively across all elements
                          '-webkit-tap-highlight-color':
                              'transparent !important',
                        },
                        // Apply to all nested elements to ensure no paragraph turns red
                        '*': {
                          '-webkit-tap-highlight-color':
                              'transparent !important',
                        },
                        'a': {'color': 'inherit', 'text-decoration': 'none'},
                        '::selection': {
                          'background': dark ? '#444444' : '#e0e0e0',
                          'color': 'inherit',
                        },
                      },
                    ),
                  ),
                  onRelocated: (cfi) => notifier.saveProgress(cfi),
                  onChaptersLoaded: (chapters) =>
                      notifier.setChapters(chapters),
                  onTextSelected: (selection) {
                    notifier.setSelection(selection);
                    final text = selection.selectedText.trim();
                    if (text.isNotEmpty) {
                      _pronounceText(text);
                    }
                    if (mounted) {
                      setState(() {});
                    }
                    debugPrint("Selected CFI: ${selection.selectionCfi}");
                  },
                ),
              );
            },
          ),
          if (state.showControls)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(12),
                color: Colors.black.withValues(alpha: 0.85),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left, color: Colors.white),
                      onPressed: () => _controller.prev(),
                    ),
                    const Expanded(
                      child: Text(
                        "Reading...",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white),
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
              ),
            ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: state.showControls ? 60.0 : 0.0),
        child: FloatingActionButton.small(
          heroTag: 'tts_small_fab',
          elevation: 6,
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          onPressed: () {
            if (_ttsService.isSpeaking) {
              _ttsService.pause();
            } else if (state.lastSelection != null &&
                state.lastSelection!.selectedText.trim().isNotEmpty) {
              _pronounceText(state.lastSelection!.selectedText);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Select text in the book to pronounce it."),
                  duration: Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
            setState(() {});
          },
          child: Icon(
            _ttsService.isSpeaking
                ? Icons.pause_rounded
                : _ttsService.isPaused
                ? Icons.play_arrow_rounded
                : Icons.volume_up_rounded,
            size: 20,
          ),
        ),
      ),
    );
  }
}
