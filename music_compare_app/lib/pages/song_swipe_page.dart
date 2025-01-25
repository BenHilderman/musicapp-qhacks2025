import 'package:flutter/material.dart';
import '../services/spotify_auth_service.dart';

class SongSwipePage extends StatefulWidget {
  final SpotifyAuthService spotifyAuthService;

  SongSwipePage({required this.spotifyAuthService});

  @override
  _SongSwipePageState createState() => _SongSwipePageState();
}

class _SongSwipePageState extends State<SongSwipePage> with SingleTickerProviderStateMixin {
  List<String> songs = []; // Replace with actual song data
  int currentIndex = 0;
  Offset position = Offset.zero;
  AnimationController? _animationController;
  Animation<Offset>? _animation;

  @override
  void initState() {
    super.initState();
    _fetchSongs();
    _animationController = AnimationController(vsync: this, duration: Duration(milliseconds: 500));
  }

  Future<void> _fetchSongs() async {
    // Fetch songs from Spotify or other sources
    List<String> fetchedSongs = await widget.spotifyAuthService.fetchSongs();
    setState(() {
      songs = fetchedSongs;
    });
  }

  @override
  void dispose() {
    _animationController?.dispose();
    super.dispose();
  }

  void _handleSwipe(DragUpdateDetails details) {
    setState(() {
      position += details.delta;
    });
  }

  void _endSwipe(DragEndDetails details) {
    if (position.dx > 100) {
      _handleSongLiked(songs[currentIndex]);
    } else if (position.dx < -100) {
      _handleSongDisliked(songs[currentIndex]);
    } else {
      _resetPosition();
    }
  }

  void _resetPosition() {
    _animation = _animationController!.drive(
      Tween(begin: position, end: Offset.zero),
    );
    _animationController!.reset();
    _animationController!.forward();
    _animationController!.addListener(() {
      setState(() {
        position = _animation!.value;
      });
    });
  }

  void _handleSongLiked(String song) {
    // Handle song liked logic
    print('Liked: $song');
    setState(() {
      currentIndex++;
      position = Offset.zero;
    });
  }

  void _handleSongDisliked(String song) {
    // Handle song disliked logic
    print('Disliked: $song');
    setState(() {
      currentIndex++;
      position = Offset.zero;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Swipe Songs'),
      ),
      body: songs.isEmpty
          ? Center(child: CircularProgressIndicator())
          : Stack(
              children: songs.asMap().entries.map((entry) {
                int index = entry.key;
                String song = entry.value;
                if (index < currentIndex) return Container();
                return Positioned(
                  top: 0,
                  bottom: 0,
                  left: position.dx,
                  right: -position.dx,
                  child: GestureDetector(
                    onPanUpdate: _handleSwipe,
                    onPanEnd: _endSwipe,
                    child: Transform.rotate(
                      angle: position.dx * 0.003,
                      child: Card(
                        child: Center(
                          child: Text(song), // Replace with song details
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }
}