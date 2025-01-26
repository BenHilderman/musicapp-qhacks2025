import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

Widget _buildReviewsTab(List<dynamic> userReviews) {
  return userReviews.isEmpty
      ? Center(
          child: Text(
            'No reviews found.',
            style: TextStyle(fontSize: 18, color: Colors.grey[400]),
          ),
        )
      : ListView.builder(
          itemCount: userReviews.length,
          itemBuilder: (context, index) {
            final review = userReviews[index];
            return Card(
              color: const Color(0xFF282828),
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: ListTile(
                leading: review['coverImage'] != null
                    ? Image.network(
                        review['coverImage'],
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                      )
                    : const Icon(
                        Icons.album,
                        color: Colors.white,
                        size: 50,
                      ),
                title: Text(
                  review['name'] ?? 'Unknown Album',
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Production: ${review['production']}, Lyrics: ${review['lyrics']}, '
                      'Flow: ${review['flow']}, Intangibles: ${review['intangibles']}',
                      style: const TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Rated on: ${DateFormat.yMMMd().format(review['timestamp'])}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            );
          },
        );
}
