import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_epub_viewer/flutter_epub_viewer.dart';

class ReaderState {
  final bool isLoading;
  final bool isDarkMode;
  final bool showControls;
  final double fontSize;
  final String fontFamily;
  final EpubLocation? currentCfi;
  final EpubTextSelection? lastSelection;
  final List<EpubChapter> chapters;

  ReaderState({
    this.isLoading = true,
    this.isDarkMode = false,
    this.showControls = true,
    this.fontSize = 16,
    this.fontFamily = 'system-ui',
    this.currentCfi,
    this.lastSelection,
    this.chapters = const [],
  });

  ReaderState copyWith({
    bool? isLoading,
    bool? isDarkMode,
    bool? showControls,
    double? fontSize,
    String? fontFamily,
    EpubLocation? currentCfi,
    EpubTextSelection? lastSelection,
    List<EpubChapter>? chapters,
  }) {
    return ReaderState(
      isLoading: isLoading ?? this.isLoading,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      showControls: showControls ?? this.showControls,
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
      currentCfi: currentCfi ?? this.currentCfi,
      lastSelection: lastSelection ?? this.lastSelection,
      chapters: chapters ?? this.chapters,
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
    // final cfi = _prefs.getString('cfi_$bookId');
    final dark = _prefs.getBool('dark_mode') ?? false;
    final fSize = _prefs.getDouble('font_size') ?? 16.0;
    final fFamily = _prefs.getString('font_family') ?? 'system-ui';

    state = state.copyWith(
      isDarkMode: dark,
      fontSize: fSize,
      fontFamily: fFamily,
      isLoading: false,
    );
  }

  void toggleControls() {
    state = state.copyWith(showControls: !state.showControls);
  }

  void toggleTheme() {
    final newValue = !state.isDarkMode;
    state = state.copyWith(isDarkMode: newValue);
    _prefs.setBool('dark_mode', newValue);
  }

  void setFontSize(double size) {
    state = state.copyWith(fontSize: size);
    _prefs.setDouble('font_size', size);
  }

  void setFontFamily(String family) {
    state = state.copyWith(fontFamily: family);
    _prefs.setString('font_family', family);
  }

  void setSelection(EpubTextSelection? selection) {
    state = state.copyWith(lastSelection: selection);
  }

  void saveProgress(EpubLocation location) {
    state = state.copyWith(currentCfi: location);
    // Use startCfi instead of cfi to match EpubLocation model
    _prefs.setString('cfi_$bookId', location.startCfi);
  }

  void setChapters(List<EpubChapter> chapters) {
    state = state.copyWith(chapters: chapters);
  }
}

/// 👉 Using family for multiple books
final readerStateProvider =
    StateNotifierProvider.family<ReaderNotifier, ReaderState, String>(
      (ref, bookId) => ReaderNotifier(bookId),
    );
