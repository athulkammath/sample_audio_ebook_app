import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_epub_viewer/flutter_epub_viewer.dart';
import '../models/ebook_annotation.dart';

enum ReaderThemePreset {
  light('Light', '#ffffff', '#000000'),
  sepia('Sepia', '#f4ecd8', '#5b4636'),
  dark('Dark', '#121212', '#ffffff'),
  slate('Slate', '#2d3748', '#e2e8f0');

  final String label;
  final String bgColor;
  final String textColor;

  const ReaderThemePreset(this.label, this.bgColor, this.textColor);
}

class ReaderState {
  final bool isLoading;
  final bool isDarkMode;
  final ReaderThemePreset themePreset;
  final EpubFlow flowMode;
  final bool showControls;
  final bool isTtsEnabled;
  final double fontSize;
  final String fontFamily;
  final String currentChapterTitle;
  final EpubLocation? currentCfi;
  final EpubTextSelection? lastSelection;
  final List<EpubChapter> chapters;
  final List<BookmarkItem> bookmarks;
  final List<HighlightItem> highlights;
  final double readingProgress;
  final int totalPages;
  final double ttsRate;

  ReaderState({
    this.isLoading = true,
    this.isDarkMode = false,
    this.themePreset = ReaderThemePreset.light,
    this.flowMode = EpubFlow.paginated,
    this.showControls = true,
    this.isTtsEnabled = false,
    this.fontSize = 16,
    this.fontFamily = 'system-ui',
    this.currentChapterTitle = '',
    this.currentCfi,
    this.lastSelection,
    this.chapters = const [],
    this.bookmarks = const [],
    this.highlights = const [],
    this.readingProgress = 0.0,
    this.totalPages = 100,
    this.ttsRate = 0.5,
  });

  int get safeTotalPages => totalPages <= 0 ? 100 : totalPages;

  int get currentPage {
    final total = safeTotalPages;
    if (readingProgress <= 0.0) return 1;
    if (readingProgress >= 1.0) return total;
    final page = (readingProgress * (total - 1)).floor() + 1;
    return page.clamp(1, total);
  }

  ReaderState copyWith({
    bool? isLoading,
    bool? isDarkMode,
    ReaderThemePreset? themePreset,
    EpubFlow? flowMode,
    bool? showControls,
    bool? isTtsEnabled,
    double? fontSize,
    String? fontFamily,
    String? currentChapterTitle,
    EpubLocation? currentCfi,
    EpubTextSelection? lastSelection,
    List<EpubChapter>? chapters,
    List<BookmarkItem>? bookmarks,
    List<HighlightItem>? highlights,
    double? readingProgress,
    int? totalPages,
    double? ttsRate,
  }) {
    return ReaderState(
      isLoading: isLoading ?? this.isLoading,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      themePreset: themePreset ?? this.themePreset,
      flowMode: flowMode ?? this.flowMode,
      showControls: showControls ?? this.showControls,
      isTtsEnabled: isTtsEnabled ?? this.isTtsEnabled,
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
      currentChapterTitle: currentChapterTitle ?? this.currentChapterTitle,
      currentCfi: currentCfi ?? this.currentCfi,
      lastSelection: lastSelection ?? this.lastSelection,
      chapters: chapters ?? this.chapters,
      bookmarks: bookmarks ?? this.bookmarks,
      highlights: highlights ?? this.highlights,
      readingProgress: readingProgress ?? this.readingProgress,
      totalPages: totalPages ?? this.totalPages,
      ttsRate: ttsRate ?? this.ttsRate,
    );
  }
}

class ReaderNotifier extends StateNotifier<ReaderState> {
  final String bookId;
  late SharedPreferences _prefs;

  ReaderNotifier(this.bookId) : super(ReaderState()) {
    _init();
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    final dark = _prefs.getBool('dark_mode') ?? false;
    final fSize = _prefs.getDouble('font_size') ?? 16.0;
    final fFamily = _prefs.getString('font_family') ?? 'system-ui';
    final themeStr =
        _prefs.getString('theme_preset_$bookId') ?? (dark ? 'dark' : 'light');
    final flowStr = _prefs.getString('flow_mode_$bookId') ?? 'paginated';
    final ttsRateVal = _prefs.getDouble('tts_rate') ?? 0.5;
    final ttsEnable = _prefs.getBool('tts_enabled_$bookId') ?? false;

    // Load Bookmarks
    final bStrList = _prefs.getStringList('bookmarks_$bookId') ?? [];
    final bList = bStrList.map((s) => BookmarkItem.decode(s)).toList();

    // Load Highlights
    final hStrList = _prefs.getStringList('highlights_$bookId') ?? [];
    final hList = hStrList.map((s) => HighlightItem.decode(s)).toList();

    ReaderThemePreset preset = ReaderThemePreset.light;
    if (themeStr == 'dark' || dark) preset = ReaderThemePreset.dark;
    if (themeStr == 'sepia') preset = ReaderThemePreset.sepia;
    if (themeStr == 'slate') preset = ReaderThemePreset.slate;

    EpubFlow flow =
        flowStr == 'scrolled' ? EpubFlow.scrolled : EpubFlow.paginated;

    state = state.copyWith(
      isDarkMode: preset == ReaderThemePreset.dark,
      themePreset: preset,
      flowMode: flow,
      isTtsEnabled: ttsEnable,
      fontSize: fSize,
      fontFamily: fFamily,
      bookmarks: bList,
      highlights: hList,
      ttsRate: ttsRateVal,
      totalPages: 100,
      isLoading: false,
    );
  }

  void toggleControls() {
    state = state.copyWith(showControls: !state.showControls);
  }

  void toggleTtsEnabled() {
    final updated = !state.isTtsEnabled;
    state = state.copyWith(isTtsEnabled: updated);
    _prefs.setBool('tts_enabled_$bookId', updated);
  }

  void toggleTheme() {
    final nextPreset = state.themePreset == ReaderThemePreset.dark
        ? ReaderThemePreset.light
        : ReaderThemePreset.dark;
    setThemePreset(nextPreset);
  }

  void setThemePreset(ReaderThemePreset preset) {
    state = state.copyWith(
      themePreset: preset,
      isDarkMode: preset == ReaderThemePreset.dark,
    );
    _prefs.setString('theme_preset_$bookId', preset.name);
    _prefs.setBool('dark_mode', preset == ReaderThemePreset.dark);
  }

  void setFlowMode(EpubFlow flow) {
    state = state.copyWith(flowMode: flow);
    _prefs.setString('flow_mode_$bookId', flow.name);
  }

  void setFontSize(double size) {
    state = state.copyWith(fontSize: size);
    _prefs.setDouble('font_size', size);
  }

  void setFontFamily(String family) {
    state = state.copyWith(fontFamily: family);
    _prefs.setString('font_family', family);
  }

  void setTtsRate(double rate) {
    state = state.copyWith(ttsRate: rate);
    _prefs.setDouble('tts_rate', rate);
  }

  void setSelection(EpubTextSelection? selection) {
    state = state.copyWith(lastSelection: selection);
  }

  void saveProgress(EpubLocation location) {
    final progress = location.progress.clamp(0.0, 1.0);
    state = state.copyWith(currentCfi: location, readingProgress: progress);
    _prefs.setString('cfi_$bookId', location.startCfi);
  }

  void setChapterTitle(String title) {
    state = state.copyWith(currentChapterTitle: title);
  }

  void setChapters(List<EpubChapter> chapters) {
    final calculatedTotal = chapters.isNotEmpty ? chapters.length * 10 : 100;
    state = state.copyWith(
      chapters: chapters,
      totalPages: calculatedTotal,
    );
  }

  void addBookmark(String cfi, String chapterTitle) {
    final newBookmark = BookmarkItem(
      cfi: cfi,
      title: chapterTitle.isEmpty ? 'Page Bookmark' : chapterTitle,
      percentage: state.readingProgress,
      createdAt: DateTime.now(),
    );
    final updated = [...state.bookmarks, newBookmark];
    state = state.copyWith(bookmarks: updated);
    _prefs.setStringList(
      'bookmarks_$bookId',
      updated.map((b) => b.encode()).toList(),
    );
  }

  void removeBookmark(BookmarkItem item) {
    final updated = state.bookmarks.where((b) => b.cfi != item.cfi).toList();
    state = state.copyWith(bookmarks: updated);
    _prefs.setStringList(
      'bookmarks_$bookId',
      updated.map((b) => b.encode()).toList(),
    );
  }

  void addHighlight(HighlightItem item) {
    final updated = [...state.highlights, item];
    state = state.copyWith(highlights: updated);
    _prefs.setStringList(
      'highlights_$bookId',
      updated.map((h) => h.encode()).toList(),
    );
  }

  void removeHighlight(HighlightItem item) {
    final updated = state.highlights.where((h) => h.cfi != item.cfi).toList();
    state = state.copyWith(highlights: updated);
    _prefs.setStringList(
      'highlights_$bookId',
      updated.map((h) => h.encode()).toList(),
    );
  }
}

/// 👉 Using family for multiple books
final readerStateProvider =
    StateNotifierProvider.family<ReaderNotifier, ReaderState, String>(
      (ref, bookId) => ReaderNotifier(bookId),
    );
