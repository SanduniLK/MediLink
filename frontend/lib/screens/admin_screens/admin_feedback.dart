import 'package:flutter/material.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  // Mock data for patient reviews
  final List<Map<String, dynamic>> _patientReviews = [
    {
      'patientName': 'Michael Brown',
      'doctorName': 'Dr. John Silva',
      'rating': 5,
      'review': 'Dr. Silva was very thorough and helpful. Highly recommended!',
    },
    {
      'patientName': 'Sarah Johnson',
      'doctorName': 'Dr. Emily Perera',
      'rating': 4,
      'review': 'Great doctor, but the wait time was a bit long.',
    },
    {
      'patientName': 'Peter Jones',
      'doctorName': 'Dr. John Silva',
      'rating': 5,
      'review': 'Excellent consultation. Very professional and knowledgeable.',
    },
  ];

  // Mock data for medical center reviews
  final List<Map<String, dynamic>> _medicalCenterReviews = [
    {
      'reviewer': 'Dr. Emily Perera',
      'centerName': 'Colombo Medical Center',
      'rating': 5,
      'review': 'The facilities are excellent and the staff is very supportive.',
    },
    {
      'reviewer': 'Dr. John Silva',
      'centerName': 'Health Mart Pharmacy',
      'rating': 4,
      'review': 'Good service, but sometimes there is a delay in prescriptions.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2, // Two tabs: one for patient reviews, one for medical center reviews
      child: Scaffold(
        backgroundColor: Colors.grey[200],
        appBar: AppBar(
          title: const Text('Feedback Management', style: TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFF18A3B6),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Color(0xFFB2DEE6),
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'Patient Reviews'),
              Tab(text: 'Medical Center Reviews'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildReviewList(_patientReviews, isPatientReview: true),
            _buildReviewList(_medicalCenterReviews, isPatientReview: false),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewList(List<Map<String, dynamic>> reviews,
      {required bool isPatientReview}) {
    if (reviews.isEmpty) {
      return const Center(child: Text('No reviews found.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: reviews.length,
      itemBuilder: (context, index) {
        final review = reviews[index];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          child: ListTile(
            title: Text(
              isPatientReview
                  ? 'Review by: ${review['patientName']}'
                  : 'Review by: ${review['reviewer']}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isPatientReview
                    ? 'For: ${review['doctorName']}'
                    : 'For: ${review['centerName']}'),
                const SizedBox(height: 4),
                Row(
                  children: List.generate(5, (starIndex) {
                    return Icon(
                      starIndex < review['rating'] ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 16,
                    );
                  }),
                ),
                const SizedBox(height: 4),
                Text(review['review']),
              ],
            ),
          ),
        );
      },
    );
  }
}
