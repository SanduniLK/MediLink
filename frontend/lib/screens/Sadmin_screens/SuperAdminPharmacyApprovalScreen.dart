import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class SuperAdminPharmacyApprovalScreen extends StatefulWidget {
  const SuperAdminPharmacyApprovalScreen({super.key});

  @override
  State<SuperAdminPharmacyApprovalScreen> createState() => _SuperAdminPharmacyApprovalScreenState();
}

class _SuperAdminPharmacyApprovalScreenState extends State<SuperAdminPharmacyApprovalScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('pharmacy_requests')
            .where('status', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final pharmacies = snapshot.data!.docs;

          if (pharmacies.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 80, color: Colors.green),
                  SizedBox(height: 16),
                  Text(
                    'No pending pharmacy requests',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: pharmacies.length,
            itemBuilder: (context, index) {
              final pharmacy = pharmacies[index];
              final data = pharmacy.data() as Map<String, dynamic>;
              
              return _buildPharmacyCard(pharmacy.id, data);
            },
          );
        },
      ),
    );
  }

  Widget _buildPharmacyCard(String pharmacyId, Map<String, dynamic> data) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pharmacy Basic Info
            Row(
              children: [
                Icon(Icons.local_pharmacy, color: Colors.blue[700], size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['name'] ?? 'No Name',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Owner: ${data['ownerName'] ?? 'No Owner Name'}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: const Text(
                    'PENDING',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  backgroundColor: Colors.orange,
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Pharmacy Details
            _buildDetailRow('Email', data['email'] ?? 'No Email'),
            _buildDetailRow('Phone', data['phone'] ?? 'No Phone'),
            _buildDetailRow('License', data['licenseNumber'] ?? 'No License'),
            _buildDetailRow('Address', data['address'] ?? 'No Address'),
            
            if (data['createdAt'] != null)
              _buildDetailRow(
                'Request Date', 
                DateFormat('MMM dd, yyyy - HH:mm').format(
                  (data['createdAt'] as Timestamp).toDate()
                ),
              ),
            
            const SizedBox(height: 16),
            
            // Approval Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _rejectPharmacy(pharmacyId),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _approvePharmacy(pharmacyId, data),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Future<void> _approvePharmacy(String pharmacyId, Map<String, dynamic> data) async {
    try {
      // 1. Update status in pharmacy_requests
      await _firestore.collection('pharmacy_requests').doc(pharmacyId).update({
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
      });

      // 2. Create document in pharmacies collection
      await _firestore.collection('pharmacies').doc(pharmacyId).set({
        'name': data['name'],
        'ownerName': data['ownerName'],
        'email': data['email'],
        'phone': data['phone'],
        'licenseNumber': data['licenseNumber'],
        'address': data['address'],
        'uid': pharmacyId,
        'createdAt': data['createdAt'],
        'approvedAt': FieldValue.serverTimestamp(),
        'status': 'active',
      });

      // 3. Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pharmacy approved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error approving pharmacy: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rejectPharmacy(String pharmacyId) async {
    try {
      await _firestore.collection('pharmacy_requests').doc(pharmacyId).update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pharmacy rejected.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error rejecting pharmacy: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}