import '../models/kabadiwala.dart';

class KabadiwalaRepository {
  static List<Kabadiwala> getMockKabadiwalas() {
    return [
      Kabadiwala(
        id: 'kb_001',
        name: 'Ramesh Kumar',
        phone: '+919876543210',
        location: 'Dharavi, Mumbai',
        latitude: 19.0330,
        longitude: 72.8530,
        distanceKm: 2.5,
        rating: 4.5,
        materialsAccepted: ['Paper', 'Metal', 'Plastic', 'E-waste', 'Other/Mixed'],
        rates: {
          'Paper': 15.0,
          'Metal': 45.0,
          'Plastic': 20.0,
          'E-waste': 60.0,
          'Other/Mixed': 10.0,
        },
        isAvailable: true,
        totalCollections: 250,
      ),
      Kabadiwala(
        id: 'kb_002',
        name: 'Suresh Patil',
        phone: '+919876543211',
        location: 'Kurla, Mumbai',
        latitude: 19.0600,
        longitude: 72.8900,
        distanceKm: 5.2,
        rating: 4.2,
        materialsAccepted: ['Paper', 'Metal', 'Plastic'],
        rates: {
          'Paper': 14.0,
          'Metal': 42.0,
          'Plastic': 18.0,
        },
        isAvailable: true,
        totalCollections: 180,
      ),
      Kabadiwala(
        id: 'kb_003',
        name: 'Amit Shah',
        phone: '+919876543212',
        location: 'Sion, Mumbai',
        latitude: 19.0440,
        longitude: 72.8630,
        distanceKm: 3.8,
        rating: 4.7,
        materialsAccepted: ['Paper', 'Metal', 'Plastic', 'E-waste'],
        rates: {
          'Paper': 16.0,
          'Metal': 48.0,
          'Plastic': 22.0,
          'E-waste': 65.0,
        },
        isAvailable: true,
        totalCollections: 320,
      ),
    ];
  }
}

