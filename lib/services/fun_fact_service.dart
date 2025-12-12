import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:walkwise/models/fun_fact.dart';

class FunFactService {
  static Future<List<FunFact>> fetchFunFacts(int cityId, String locationName) async {
    final query = await FirebaseFirestore.instance
        .collection('funfacts')
        .where('city_id', isEqualTo: cityId)
        .where('location_name', isEqualTo: locationName)
        .get();
    return query.docs.map((doc) => FunFact.fromFirestore(doc.data())).toList();
  }
} 