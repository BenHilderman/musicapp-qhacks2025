import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import '../env.dart';
import '../services/api_helper.dart'; // Spotify API helper
import 'package:intl/intl.dart'; // For formatting timestamps

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

  Future<void> _submitRating() async {
    try {
      // Ensure the user has an email
      if (spotifyUserEmail == null) {
        _showEmailRequiredDialog();
        return;
      }

      try {
        // Step 1: Check if the album exists in the ALBUM table
        String? albumObjectId;
        final QueryBuilder<ParseObject> albumQuery =
            QueryBuilder<ParseObject>(ParseObject('ALBUM'))
              ..whereEqualTo('albumID', widget.albumId); // Match albumID
        final ParseResponse albumResponse = await albumQuery.query();

        if (albumResponse.success &&
            albumResponse.results != null &&
            albumResponse.results!.isNotEmpty) {
          // Album exists
          final ParseObject album = albumResponse.results!.first as ParseObject;
          albumObjectId = album.objectId;
        } else {
          // Album does not exist, create it
          final ParseObject newAlbum = ParseObject('ALBUM')
            ..set('albumID', widget.albumId);
          final ParseResponse saveAlbumResponse = await newAlbum.save();
          if (saveAlbumResponse.success) {
            albumObjectId = newAlbum.objectId;
          } else {
            print('Failed to save album: ${saveAlbumResponse.error?.message}');
            return;
          }
        }

        // Step 2: Check if the user exists in the _User table
        String? userObjectId;
        final QueryBuilder<ParseObject> userQuery =
            QueryBuilder<ParseObject>(ParseObject('USER'))
              ..whereEqualTo('email', spotifyUserEmail); // Match email
        final ParseResponse userResponse = await userQuery.query();

        if (userResponse.success &&
            userResponse.results != null &&
            userResponse.results!.isNotEmpty) {
          // User exists
          final ParseObject user = userResponse.results!.first as ParseObject;
          userObjectId = user.objectId;
        } else {
          // User does not exist, create it with email as objectId
          final ParseObject newUser = ParseObject('USER')
            ..set('email', spotifyUserEmail); // Set email field
          final ParseResponse saveUserResponse = await newUser.save();
          if (saveUserResponse.success) {
            userObjectId = newUser.objectId;
          } else {
            print('Failed to save user: ${saveUserResponse.error?.message}');
            return;
          }
        }

        // Step 3: Save the RATING object with pointers to ALBUM and USER
        if (albumObjectId != null && userObjectId != null) {
          final ParseObject rating = ParseObject('RATINGS')
            ..set('user',
                ParseObject('USER')..objectId = userObjectId) // Pointer to User
            ..set(
                'albumID',
                ParseObject('ALBUM')
                  ..objectId = albumObjectId) // Pointer to Album
            ..set('production', production)
            ..set('lyrics', lyrics)
            ..set('flow', flow)
            ..set('intangibles', intangibles)
            ..set('timestamp', DateTime.now()); // Current timestamp

          final ParseResponse ratingResponse = await rating.save();
          if (ratingResponse.success) {
            print('Rating saved successfully!');
          } else {
            print('Failed to save rating: ${ratingResponse.error?.message}');
          }
        }
      } catch (e) {
        print('Error saving rating: $e');
      }
    } catch (e) {
      print("Error submitting rating: $e");
    }
  }

  void _showEmailRequiredDialog() {
    // Show a dialog to inform the user that an email is required
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Email Required"),
        content: Text(
            "You must have an email associated with your account to submit a rating."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text("OK"),
          ),
        ],
      ),
    );
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
              : _buildAlbumDetails(),
    );
  }

  Widget _buildAlbumDetails() {
    return Padding(
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
                final track = albumDetails!['tracks']['items'][index];
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
            child: ElevatedButton(
              onPressed: _submitRating,
              style: ElevatedButton.styleFrom(
                backgroundColor: spotifyGreen,
              ),
              child: Text(
                'Submit Rating',
                style: TextStyle(
                  color: darkBackground,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
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
