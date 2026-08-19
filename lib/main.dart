import 'package:audio_ebook_library/core/services/audio_handler.dart';
import 'package:audio_ebook_library/core/services/file_service.dart';
import 'package:audio_ebook_library/features/audio/pages/audio_player_page.dart';
import 'package:audio_ebook_library/features/ebook/pages/ebook_reader_page.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Audio Service
  audioHandler = await AudioService.init(
    builder: () => MyAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId:
          'com.example.audio_ebook_library.channel.audio',
      androidNotificationChannelName: 'Audiobook Playback',
      androidStopForegroundOnPause: true,
    ),
  );

  // Sync assets to local storage for robust access
  try {
    await FileService.copyAssetToFile('assets/ebooks/alice.epub');
    await FileService.copyAssetToFile('assets/audio/sample.mp3');
    debugPrint("Assets synced to local storage.");
  } catch (e) {
    debugPrint("Error syncing assets: $e");
  }

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'E-Book & Audiobook Reader',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Audiobook Library")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildActionCard(
              context,
              title: "Read E-Book",
              subtitle: "Alice's Adventures in Wonderland",
              icon: Icons.book,
              onTap: () async {
                final path = await FileService.copyAssetToFile(
                  'assets/ebooks/alice.epub',
                );
                if (context.mounted) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => EbookReaderPage(assetPath: path),
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 24),
            _buildActionCard(
              context,
              title: "Play Audiobook",
              subtitle: "Listen to sample audiobook in background",
              icon: Icons.headphones,
              onTap: () async {
                final path = await FileService.copyAssetToFile(
                  'assets/audio/sample.mp3',
                );
                if (context.mounted) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => AudioPlayerPage(
                        audioAssetPath: path,
                        title: "Sample Audiobook",
                      ),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            children: [
              Icon(
                icon,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
