import 'package:flutter/material.dart';
import 'package:uni_links/uni_links.dart';  // Import uni_links
import 'dart:async';
import 'pages/song_swipe_page.dart';
import 'pages/song_search_page.dart';
import 'pages/profile_page.dart';
import 'services/spotify_auth_service.dart';

void main() {
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

  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> _pages = [
      SongSwipePage(spotifyAuthService: _spotifyAuthService),
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
        primarySwatch: Colors.blue,
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
          selectedItemColor: Colors.blue,
          onTap: _onItemTapped,
        ),
      ),
    );
  }
}