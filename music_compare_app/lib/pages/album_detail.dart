import 'package:flutter/material.dart';
import '../services/api_helper.dart'; // Spotify API helper

class AlbumDetailPage extends StatefulWidget {
  final String albumId; // ID of the album

  const AlbumDetailPage({Key? key, required this.albumId}) : super(key: key);

  @override
  _AlbumDetailPageState createState() => _AlbumDetailPageState();
}

class _AlbumDetailPageState extends State<AlbumDetailPage> {
  Map<String, dynamic>? albumDetails; // Nullable variable to store album details

  bool isLoading = true;

  final SpotifyAPI spotifyAPI = SpotifyAPI();

  @override
  void initState() {
    super.initState();
    fetchAlbumDetails(widget.albumId); // Fetch album details on page load
  }

  Future<void> fetchAlbumDetails(String albumId) async {
    try {
      setState(() {
        isLoading = true; // Show loading spinner
      });

      // Fetch album details from the Spotify API
      final details = await spotifyAPI.fetchAlbumDetails(albumId);
      setState(() {
        albumDetails = details; // Store the details
        isLoading = false; // Hide loading spinner
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      print("Error fetching album details: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(albumDetails?['name'] ?? 'Album Details'), // Handle null safely
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator()) // Show loading spinner
          : albumDetails == null
              ? Center(child: Text("Album not found")) // Handle null album details
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Display album image, safely checking albumDetails
                      if (albumDetails!['images'] != null && albumDetails!['images'].isNotEmpty)
                        Image.network(
                          albumDetails!['images'][0]['url'],
                          width: 150,
                          height: 150,
                          fit: BoxFit.cover,
                        ),
                      SizedBox(width: 16),
                      // Display album details and track list to the right of the album cover
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Display album name and release date, with null checks
                            Text(
                              albumDetails!['name'] ?? 'Unknown',
                              style: TextStyle(
                                fontSize: 24, // Custom font size for album name
                                fontWeight: FontWeight.bold, // Bold for title
                              ),
                            ),
                            Text(
                              'Released: ${albumDetails!['release_date'] ?? 'Unknown'}',
                              style: TextStyle(
                                fontSize: 16, // Custom font size for release date
                                color: Colors.grey, // Slightly grey for subtitle
                              ),
                            ),
                            SizedBox(height: 16),
                            // Track list section
                            Text("Tracks:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                            Expanded(
                              child: ListView.builder(
                                itemCount: albumDetails!['tracks']['items'].length,
                                itemBuilder: (context, index) {
                                  final track = albumDetails!['tracks']['items'][index];
                                  return ListTile(
                                    title: Text("${index + 1}. ${track['name']}"),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
