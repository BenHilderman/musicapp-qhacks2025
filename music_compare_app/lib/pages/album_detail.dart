import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import '../env.dart';
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
  bool hasRated = false;
  Map<String, dynamic>? userRating;

  int production = 50;
  int lyrics = 50;
  int flow = 50;
  int intangibles = 50;

  final SpotifyAPI spotifyAPI = SpotifyAPI();
  final Color spotifyGreen = const Color(0xFF1DB954);
  final Color darkBackground = const Color(0xFF191414);
  final Color darkCard = const Color(0xFF282828);
  final Color textColor = Colors.white;

  double get totalRating => (production + lyrics + flow + intangibles) / 4.0;

  @override
  void initState() {
    super.initState();
    fetchAlbumDetails(widget.albumId);
    checkUserRating();
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

  Future<void> checkUserRating() async {
    try {
      if (spotifyUserEmail == null) return;

      // Query to check if the user has rated this album
      final QueryBuilder<ParseObject> ratingQuery =
          QueryBuilder<ParseObject>(ParseObject('RATINGS'))
            ..whereEqualTo('albumID', widget.albumId)
            ..whereEqualTo('user', spotifyUserEmail);

      final ParseResponse ratingResponse = await ratingQuery.query();

      if (ratingResponse.success &&
          ratingResponse.results != null &&
          ratingResponse.results!.isNotEmpty) {
        final ParseObject rating = ratingResponse.results!.first as ParseObject;

        setState(() {
          hasRated = true;
          userRating = {
            'production': rating.get<int>('production') ?? 0,
            'lyrics': rating.get<int>('lyrics') ?? 0,
            'flow': rating.get<int>('flow') ?? 0,
            'intangibles': rating.get<int>('intangibles') ?? 0,
          };
        });
      } else {
        setState(() {
          hasRated = false;
          userRating = null;
        });
      }
    } catch (e) {
      print('Error checking user rating: $e');
      setState(() {
        hasRated = false;
        userRating = null;
      });
    }
  }

  Future<void> _submitRating() async {
    if (hasRated) return;

    try {
      if (spotifyUserEmail == null) return;

      // Ensure album exists or create it
      String? albumObjectId;
      final QueryBuilder<ParseObject> albumQuery =
          QueryBuilder<ParseObject>(ParseObject('ALBUM'))
            ..whereEqualTo('albumID', widget.albumId);
      final ParseResponse albumResponse = await albumQuery.query();

      if (albumResponse.success &&
          albumResponse.results != null &&
          albumResponse.results!.isNotEmpty) {
        albumObjectId = (albumResponse.results!.first as ParseObject).objectId;
      } else {
        final ParseObject newAlbum = ParseObject('ALBUM')
          ..set('albumID', widget.albumId);
        final ParseResponse newAlbumResponse = await newAlbum.save();
        if (newAlbumResponse.success) {
          albumObjectId = newAlbum.objectId;
        } else {
          print('Failed to save album: ${newAlbumResponse.error?.message}');
          return;
        }
      }

      // Ensure user exists or create it
      String? userObjectId;
      final QueryBuilder<ParseObject> userQuery =
          QueryBuilder<ParseObject>(ParseObject('USER'))
            ..whereEqualTo('email', spotifyUserEmail);
      final ParseResponse userResponse = await userQuery.query();

      if (userResponse.success &&
          userResponse.results != null &&
          userResponse.results!.isNotEmpty) {
        userObjectId = (userResponse.results!.first as ParseObject).objectId;
      } else {
        final ParseObject newUser = ParseObject('USER')
          ..set('email', spotifyUserEmail);
        final ParseResponse newUserResponse = await newUser.save();
        if (newUserResponse.success) {
          userObjectId = newUser.objectId;
        } else {
          print('Failed to save user: ${newUserResponse.error?.message}');
          return;
        }
      }

      // Save the rating
      final ParseObject rating = ParseObject('RATINGS')
        ..set('user', ParseObject('USER')..objectId = userObjectId)
        ..set('albumID', ParseObject('ALBUM')..objectId = albumObjectId)
        ..set('production', production)
        ..set('lyrics', lyrics)
        ..set('flow', flow)
        ..set('intangibles', intangibles)
        ..set('timestamp', DateTime.now());

      final ParseResponse ratingResponse = await rating.save();
      if (ratingResponse.success) {
        setState(() {
          hasRated = true;
          userRating = {
            'production': production,
            'lyrics': lyrics,
            'flow': flow,
            'intangibles': intangibles,
          };
        });
        print('Rating saved successfully!');
      } else {
        print('Failed to save rating: ${ratingResponse.error?.message}');
      }
    } catch (e) {
      print("Error submitting rating: $e");
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
              : _buildAlbumDetails(),
    );
  }

  Widget _buildAlbumDetails() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (albumDetails?['images'] != null &&
                    albumDetails?['images'].isNotEmpty)
                  Image.network(
                    albumDetails?['images'][0]['url'] ?? '',
                    width: 150,
                    height: 150,
                    fit: BoxFit.cover,
                  ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        albumDetails?['name'] ?? 'Unknown',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      Text(
                        'Released: ${albumDetails?['release_date'] ?? 'Unknown'}',
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
            const SizedBox(height: 16),
            Text(
              "Tracks:",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: albumDetails?['tracks']['items']?.length ?? 0,
              itemBuilder: (context, index) {
                final track = albumDetails?['tracks']['items'][index];
                return ListTile(
                  title: Text(
                    "${index + 1}. ${track['name']}",
                    style: TextStyle(color: textColor),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            if (hasRated && userRating != null) ...[
              Text(
                "Your Rating:",
                style: TextStyle(fontSize: 18, color: textColor),
              ),
              Text(
                "Production: ${userRating!['production']}",
                style: TextStyle(color: textColor),
              ),
              Text(
                "Lyrics: ${userRating!['lyrics']}",
                style: TextStyle(color: textColor),
              ),
              Text(
                "Flow: ${userRating!['flow']}",
                style: TextStyle(color: textColor),
              ),
              Text(
                "Intangibles: ${userRating!['intangibles']}",
                style: TextStyle(color: textColor),
              ),
            ] else ...[
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
              const SizedBox(height: 16),
              Center(
                child: ElevatedButton(
                  onPressed: _submitRating,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: spotifyGreen,
                    textStyle: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  child: const Text(
                    "Submit Rating",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
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
