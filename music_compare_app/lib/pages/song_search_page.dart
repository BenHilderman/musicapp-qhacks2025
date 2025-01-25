import 'package:flutter/material.dart';
import '../services/api_helper.dart'; // Import the Spotify API helper
import 'album_detail.dart'; // Import the AlbumDetail page

class SongSearchPage extends StatefulWidget {
  @override
  _SongSearchPageState createState() => _SongSearchPageState();
}

class _SongSearchPageState extends State<SongSearchPage> {
  TextEditingController searchController = TextEditingController();
  List<Map<String, String>> searchResults = []; // To hold search results
  bool isLoading = false;

  final SpotifyAPI spotifyAPI = SpotifyAPI(); // Spotify API instance

  // Spotify color palette
  final Color spotifyGreen = Color(0xFF1DB954);
  final Color darkBackground = Color(0xFF191414);
  final Color darkCard = Color(0xFF282828);
  final Color textColor = Colors.white;

  // Function to search for albums
  Future<void> searchAlbums(String query) async {
    if (query.isEmpty) return; // Don't search if the query is empty

    setState(() {
      isLoading = true; // Show loading spinner
    });

    try {
      // Fetch albums from the API
      final albums = await spotifyAPI.searchAlbums(query);
      setState(() {
        searchResults = albums;
        isLoading = false; // Hide loading spinner
      });
    } catch (e) {
      setState(() {
        isLoading = false; // Hide loading spinner
      });
      print("Error searching albums: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBackground,
      appBar: AppBar(
        backgroundColor: darkCard,
        title: Text(
          'Search Albums',
          style: TextStyle(color: textColor),
        ),
        iconTheme: IconThemeData(color: textColor),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Search input
            TextField(
              controller: searchController,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                filled: true,
                fillColor: darkCard,
                labelText: 'Search for an album',
                labelStyle: TextStyle(color: textColor),
                suffixIcon: IconButton(
                  icon: Icon(Icons.search, color: spotifyGreen),
                  onPressed: () => searchAlbums(searchController.text),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            SizedBox(height: 16),

            // Display results
            isLoading
                ? Center(
                    child: CircularProgressIndicator(
                        color: spotifyGreen)) // Show loading spinner
                : Expanded(
                    child: ListView.builder(
                      itemCount: searchResults.length,
                      itemBuilder: (context, index) {
                        final album = searchResults[index];

                        // Correctly accessing the album title and image
                        final albumTitle = album['title'];
                        final albumArtist = album['artist'];
                        final albumImage = album['image'];

                        return Card(
                          color: darkCard,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListTile(
                            contentPadding: EdgeInsets.symmetric(
                                vertical: 10, horizontal: 16),
                            leading: Image.network(
                              albumImage!,
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                            ),
                            title: Text(
                              albumTitle!,
                              style: TextStyle(color: textColor),
                            ),
                            subtitle: Text(
                              albumArtist!,
                              style:
                                  TextStyle(color: textColor.withOpacity(0.7)),
                            ),
                            onTap: () {
                              // Navigate to the album detail page
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AlbumDetailPage(
                                    albumId: album[
                                        'id']!, // Pass album ID to details page
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
