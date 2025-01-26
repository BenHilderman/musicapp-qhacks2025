import 'package:flutter/material.dart';
import 'package:uni_links/uni_links.dart'; // Import uni_links
import 'dart:async';
import 'pages/song_swipe_page.dart';
import 'pages/song_search_page.dart';
import 'pages/profile_page.dart';
import 'services/spotify_auth_service.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart'; // Correct import

Future<void> main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  final keyApplicationId = 'TzIHO5q1E6K6jVsYTMvL3eoCWLTkztT3JsJ8F770';
  final keyClientKey = 'eFtlbDLK4mHiuHamZnbJESmwAaU6qcsgmwalCEVY';
  final keyParseServerUrl = 'https://parseapi.back4app.com';

  // Initialize Parse server
  await Parse().initialize(
    keyApplicationId,
    keyParseServerUrl,
    clientKey: keyClientKey,
    autoSendSessionId: true,
  );

  // Run the app
  runApp(MusicCompareApp());
}

class MusicCompareApp extends StatefulWidget {
  @override
  _MusicCompareAppState createState() => _MusicCompareAppState();
}

class _MusicCompareAppState extends State<MusicCompareApp> {
  final SpotifyAuthService _spotifyAuthService = getSpotifyAuthService();
  bool _isSignedIn = false;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _checkSignInStatus();
    _handleIncomingLinks();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _checkSignInStatus() async {
    final accessToken = await _spotifyAuthService.handleRedirect(Uri.parse(''));
    if (accessToken != null) {
      setState(() {
        _isSignedIn = true;
      });
      await _spotifyAuthService.fetchUserProfile();
      await _spotifyAuthService.fetchUserPlaylists();
    }
  }

  Future<void> _signIn() async {
    await _spotifyAuthService.signIn();
    await _checkSignInStatus();
  }

  void _handleIncomingLinks() {
    _sub = uriLinkStream.listen((Uri? uri) async {
      if (uri != null) {
        final accessToken = await _spotifyAuthService.handleRedirect(uri);
        if (accessToken != null) {
          setState(() {
            _isSignedIn = true;
          });
          await _spotifyAuthService.fetchUserProfile();
          await _spotifyAuthService.fetchUserPlaylists();
        }
      }
    }, onError: (err) {
      // Handle error
    });
  }

  int _selectedIndex = 1; // Set ProfilePage to be the first screen

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> _pages = [
      SongSwipePage(),
      ProfilePage(
        spotifyAuthService: _spotifyAuthService,
        isSignedIn: _isSignedIn,
        signIn: _signIn,
      ),
      SongSearchPage(),
    ];

    return MaterialApp(
      title: 'Music Compare',
      theme: ThemeData(
        primaryColor: Color(0xFF1DB954), // Spotify green
        scaffoldBackgroundColor: Colors.black,
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: Colors.black,
          selectedItemColor: Color(0xFF1DB954),
          unselectedItemColor: Colors.white,
        ),
        textTheme: TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.black,
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 20),
        ),
        colorScheme:
            ColorScheme.fromSwatch().copyWith(secondary: Color(0xFF1DB954)),
      ),
      home: Scaffold(
        body: _pages[_selectedIndex],
        bottomNavigationBar: BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.swap_horiz),
              label: 'Swipe',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profile',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.search),
              label: 'Search',
            ),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: Color(0xFF1DB954), // Spotify green
          unselectedItemColor: Colors.white,
          onTap: _onItemTapped,
        ),
      ),
    );
  }
}
