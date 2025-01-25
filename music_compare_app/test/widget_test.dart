import 'package:flutter/material.dart';

void main() {
  runApp(MusicCompareApp());
}

class MusicCompareApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Music Compare',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: SongComparePage(),
    );
  }
}

class SongComparePage extends StatefulWidget {
  @override
  _SongComparePageState createState() => _SongComparePageState();
}

class _SongComparePageState extends State<SongComparePage> {
  List<Map<String, String>> songs = [
    {"title": "Song 1", "artist": "Artist 1", "image": "assets/song1.jpg"},
    {"title": "Song 2", "artist": "Artist 2", "image": "assets/song2.jpg"},
    {"title": "Song 3", "artist": "Artist 3", "image": "assets/song3.jpg"},
    {"title": "Song 4", "artist": "Artist 4", "image": "assets/song4.jpg"},
    {"title": "Song 5", "artist": "Artist 5", "image": "assets/song5.jpg"},
  ];

  int currentIndex = 0;

  void _handleSwipe(String songTitle, String direction) {
    int score = direction == "right" ? 10 : 1;
    print("$songTitle rated: $score");

    setState(() {
      // Move to the next pair of songs
      currentIndex += 2;
      if (currentIndex >= songs.length - 1) {
        currentIndex = 0; // Restart when songs are finished
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (currentIndex + 1 >= songs.length) {
      return Scaffold(
        appBar: AppBar(title: Text("Compare Songs")),
        body: Center(
          child: Text("No more songs to compare!"),
        ),
      );
    }

    final song1 = songs[currentIndex];
    final song2 = songs[currentIndex + 1];

    return Scaffold(
      appBar: AppBar(
        title: Text("Compare Songs"),
      ),
      body: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onHorizontalDragEnd: (details) {
                String direction =
                    details.primaryVelocity! > 0 ? "right" : "left";
                _handleSwipe(song1["title"]!, direction);
              },
              child: SongCard(
                title: song1["title"]!,
                artist: song1["artist"]!,
                image: song1["image"]!,
              ),
            ),
          ),
          VerticalDivider(
            color: Colors.grey,
            width: 1,
          ),
          Expanded(
            child: GestureDetector(
              onHorizontalDragEnd: (details) {
                String direction =
                    details.primaryVelocity! > 0 ? "right" : "left";
                _handleSwipe(song2["title"]!, direction);
              },
              child: SongCard(
                title: song2["title"]!,
                artist: song2["artist"]!,
                image: song2["image"]!,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SongCard extends StatelessWidget {
  final String title;
  final String artist;
  final String image;

  SongCard({required this.title, required this.artist, required this.image});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16.0),
            child: Image.asset(
              image,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16.0),
              gradient: LinearGradient(
                colors: [Colors.transparent, Colors.black54],
                stops: [0.5, 1.0],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Positioned(
            bottom: 16.0,
            left: 16.0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  artist,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16.0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
