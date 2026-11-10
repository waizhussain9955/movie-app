import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'screens/home_screen.dart';
import 'screens/search_screen.dart';
import 'screens/player_screen.dart';
import 'services/download_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DownloadService().init();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0F0F0F),
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );
  runApp(const StreamMaxApp());
}

class StreamMaxApp extends StatelessWidget {
  const StreamMaxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StreamMax',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0C10),
        primaryColor: const Color(0xFFE50914),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFE50914),
          secondary: Color(0xFFE50914),
          surface: Color(0xFF131720),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0A0C10),
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        useMaterial3: true,
      ),
      home: const MainNavigationShell(),
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;
  DateTime? _lastBackPressTime;

  final List<Widget> _tabs = [
    const HomeScreen(),
    const SearchScreen(),
    const RealDownloadsTab(),
    const ProfilePlaceholderTab(),
  ];

  @override
  Widget build(BuildContext context) {
    // Prevent accidental app close on back button
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;

        // If not on Home tab, go to Home tab first
        if (_currentIndex != 0) {
          setState(() => _currentIndex = 0);
          return;
        }

        // Double tap back to exit
        final now = DateTime.now();
        if (_lastBackPressTime == null || now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Press back again to exit'),
              duration: Duration(seconds: 2),
              backgroundColor: Color(0xFF222222),
            ),
          );
          return;
        }

        SystemNavigator.pop();
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: _tabs,
        ),
        bottomNavigationBar: Container(
          color: const Color(0xFF0A0C10),
          child: SafeArea(
            top: false,
            bottom: true,
            maintainBottomViewPadding: true,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0F1218),
                border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.06), width: 1)),
              ),
              child: Theme(
                data: Theme.of(context).copyWith(
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                ),
                child: BottomNavigationBar(
                  currentIndex: _currentIndex,
                  backgroundColor: const Color(0xFF0F1218),
                  selectedItemColor: const Color(0xFFE50914),
                  unselectedItemColor: const Color(0xFF7E8695),
                  type: BottomNavigationBarType.fixed,
                  elevation: 0,
                  selectedFontSize: 11,
                  unselectedFontSize: 11,
                  selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, height: 1.4),
                  unselectedLabelStyle: const TextStyle(height: 1.4),
                  onTap: (index) => setState(() => _currentIndex = index),
                  items: const [
                    BottomNavigationBarItem(
                      icon: Padding(
                        padding: EdgeInsets.only(bottom: 2),
                        child: Icon(Icons.home_outlined),
                      ),
                      activeIcon: Padding(
                        padding: EdgeInsets.only(bottom: 2),
                        child: Icon(Icons.home_filled),
                      ),
                      label: 'Home',
                    ),
                    BottomNavigationBarItem(
                      icon: Padding(
                        padding: EdgeInsets.only(bottom: 2),
                        child: Icon(Icons.search_outlined),
                      ),
                      activeIcon: Padding(
                        padding: EdgeInsets.only(bottom: 2),
                        child: Icon(Icons.search),
                      ),
                      label: 'Search',
                    ),
                    BottomNavigationBarItem(
                      icon: Padding(
                        padding: EdgeInsets.only(bottom: 2),
                        child: Icon(Icons.file_download_outlined),
                      ),
                      activeIcon: Padding(
                        padding: EdgeInsets.only(bottom: 2),
                        child: Icon(Icons.file_download),
                      ),
                      label: 'Downloads',
                    ),
                    BottomNavigationBarItem(
                      icon: Padding(
                        padding: EdgeInsets.only(bottom: 2),
                        child: Icon(Icons.person_outline),
                      ),
                      activeIcon: Padding(
                        padding: EdgeInsets.only(bottom: 2),
                        child: Icon(Icons.person),
                      ),
                      label: 'Me',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fully Functional Real Persistent Downloads Tab
class RealDownloadsTab extends StatelessWidget {
  const RealDownloadsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text('My Downloads', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ValueListenableBuilder<List<DownloadItem>>(
        valueListenable: DownloadService().downloadsNotifier,
        builder: (context, downloads, _) {
          if (downloads.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.download_for_offline_outlined, size: 72, color: Colors.grey[700]),
                  const SizedBox(height: 16),
                  const Text(
                    'No Downloads Yet',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Movies and shows you download will appear here for offline viewing.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[500], fontSize: 13),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: downloads.length,
            itemBuilder: (context, idx) {
              final item = downloads[idx];
              final movie = item.movie;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF131720),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF202634)),
                ),
                child: Row(
                  children: [
                    // Movie Thumbnail
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        width: 60,
                        height: 85,
                        child: movie.posterUrl != null
                            ? CachedNetworkImage(
                                imageUrl: movie.posterUrl!,
                                fit: BoxFit.cover,
                                placeholder: (_, _) => Container(color: Colors.black26),
                                errorWidget: (_, _, _) => Container(color: Colors.black26),
                              )
                            : Container(color: Colors.black26),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Details & Progress Bar
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            movie.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.isCompleted
                                ? 'Ready to watch offline • ${item.size}'
                                : 'Downloading • ${(item.progress * 100).toInt()}% (${item.speed})',
                            style: TextStyle(
                              color: item.isCompleted ? Colors.green : Colors.grey[400],
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (!item.isCompleted)
                            LinearProgressIndicator(
                              value: item.progress,
                              backgroundColor: Colors.white12,
                              color: const Color(0xFFE50914),
                              minHeight: 4,
                            ),
                        ],
                      ),
                    ),

                    // Action Icon
                    if (item.isCompleted)
                      IconButton(
                        icon: const Icon(Icons.play_circle_fill, color: Color(0xFFE50914), size: 36),
                        tooltip: 'Watch Offline',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PlayerScreen(
                                movie: movie,
                                servers: movie.servers,
                                localFilePath: item.localPath,
                              ),
                            ),
                          );
                        },
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                        onPressed: () {
                          DownloadService().removeDownload(movie.id);
                        },
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class ProfilePlaceholderTab extends StatelessWidget {
  const ProfilePlaceholderTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(title: const Text('My Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Center(
            child: CircleAvatar(
              radius: 40,
              backgroundColor: Color(0xFFE50914),
              child: Icon(Icons.person, size: 48, color: Colors.white),
            ),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'Guest User (Guest Mode Active)',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              'Device ID: SM-${DateTime.now().year}-GUEST',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ),
          const SizedBox(height: 28),
          _buildSettingTile(Icons.cast, 'Cast to Smart TV / Chromecast', 'Configure DLNA & AirPlay'),
          _buildSettingTile(Icons.high_quality, 'Default Video Quality', '1080p Full HD'),
          _buildSettingTile(Icons.wifi, 'Download on Wi-Fi Only', 'Enabled'),
          _buildSettingTile(Icons.lock_outline, 'Parental Control (Kids PIN)', 'Disabled'),
          _buildSettingTile(Icons.info_outline, 'About StreamMax', 'v1.0.0 (Reverse Engineered Edition)'),
        ],
      ),
    );
  }

  Widget _buildSettingTile(IconData icon, String title, String subtitle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF131720),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF202634)),
      ),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFFE50914)),
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(color: Color(0xFF9EA3AE), fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, color: Color(0xFF7E8695)),
      ),
    );
  }
}
