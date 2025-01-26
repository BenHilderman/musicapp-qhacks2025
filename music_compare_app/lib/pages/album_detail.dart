import 'package:flutter/material.dart';
import '../services/api_helper.dart'; // Spotify API helper

class AlbumDetailPage extends StatefulWidget {
  final String albumId; // ID of the album

  const AlbumDetailPage({Key? key, required this.albumId}) : super(key: key);

  @override
  _AlbumDetailPageState createState() => _AlbumDetailPageState();
}

class _AlbumDetailPageState extends State<AlbumDetailPage> {
  Map<String, dynamic>? albumDetails;
  bool isLoading = true;

  int production = 50;
  int lyrics = 50;
  int flow = 50;
  int intangibles = 50;

  final SpotifyAPI spotifyAPI = SpotifyAPI();
  final Color spotifyGreen = Color(0xFF1DB954);
  final Color darkBackground = Color(0xFF191414);
  final Color darkCard = Color(0xFF282828);
  final Color textColor = Colors.white;

  double get totalRating => (production + lyrics + flow + intangibles) / 4.0;

  @override
  void initState() {
    super.initState();
    fetchAlbumDetails(widget.albumId);
  }

  Future<void> fetchAlbumDetails(String albumId) async {
    try {
      setState(() {
        isLoading = true;
      });

      final details = await spotifyAPI.fetchAlbumDetails(albumId);
      setState(() {
        albumDetails = details;
        isLoading = false;
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
      backgroundColor: darkBackground,
      appBar: AppBar(
        backgroundColor: darkCard,
        title: Text(
          albumDetails?['name'] ?? 'Album Details',
          style: TextStyle(color: textColor),
        ),
        iconTheme: IconThemeData(color: textColor),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: spotifyGreen))
          : albumDetails == null
              ? Center(
                  child: Text(
                    "Album not found",
                    style: TextStyle(color: textColor),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (albumDetails!['images'] != null &&
                              albumDetails!['images'].isNotEmpty)
                            Image.network(
                              albumDetails!['images'][0]['url'],
                              width: 150,
                              height: 150,
                              fit: BoxFit.cover,
                            ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  albumDetails!['name'] ?? 'Unknown',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                                Text(
                                  'Released: ${albumDetails!['release_date'] ?? 'Unknown'}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: textColor.withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Text(
                        "Tracks:",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: textColor,
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: albumDetails!['tracks']['items'].length,
                          itemBuilder: (context, index) {
                            final track =
                                albumDetails!['tracks']['items'][index];
                            return ListTile(
                              title: Text(
                                "${index + 1}. ${track['name']}",
                                style: TextStyle(color: textColor),
                              ),
                            );
                          },
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Rate this Album',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      SizedBox(height: 16),
                      _buildRatingSlider('Production', (value) {
                        setState(() {
                          production = value.toInt();
                        });
                      }, production),
                      _buildRatingSlider('Lyrics', (value) {
                        setState(() {
                          lyrics = value.toInt();
                        });
                      }, lyrics),
                      _buildRatingSlider('Flow', (value) {
                        setState(() {
                          flow = value.toInt();
                        });
                      }, flow),
                      _buildRatingSlider('Intangibles', (value) {
                        setState(() {
                          intangibles = value.toInt();
                        });
                      }, intangibles),
                      SizedBox(height: 16),
                      Center(
                        child: Text(
                          'Your Overall Rating: ${totalRating.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: spotifyGreen,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildRatingSlider(
      String label, ValueChanged<double> onChanged, int value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 16, color: textColor),
        ),
        Slider(
          value: value.toDouble(),
          min: 0,
          max: 99,
          divisions: 99,
          label: value.toString(),
          activeColor: spotifyGreen,
          inactiveColor: textColor.withOpacity(0.3),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
