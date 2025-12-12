import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CityListPage extends StatefulWidget {
  const CityListPage({super.key});

  @override
  State<CityListPage> createState() => _CityListPageState();
}

class _CityListPageState extends State<CityListPage> {
  Future<QuerySnapshot> getCities() {
    return FirebaseFirestore.instance.collection('cities').get();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Choose a Venue',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      backgroundColor: Colors.white,
      body: FutureBuilder<QuerySnapshot>(
        future: getCities(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No cities found.'));
          }

          final cities = snapshot.data!.docs;

          // Sort cities alphabetically by name
          cities.sort((a, b) {
            final nameA = a['name'] as String? ?? '';
            final nameB = b['name'] as String? ?? '';
            return nameA.compareTo(nameB);
          });

          return ListView.builder(
            itemCount: cities.length,
            itemBuilder: (context, index) {
              final city = cities[index];
              final cityName = city['name'] as String? ?? 'Unnamed City';
              return ListTile(
                title: Text(cityName),
              );
            },
          );
        },
      ),
    );
  }
} 