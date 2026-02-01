import 'dart:convert';
import 'package:http/http.dart' as http;

class LocationSuggestion {
  final String displayName;
  final String title;
  final String subtitle;
  final String? city;
  final double lat;
  final double lon;

  LocationSuggestion({
    required this.displayName,
    required this.title,
    required this.subtitle,
    this.city,
    required this.lat,
    required this.lon,
  });

  factory LocationSuggestion.fromJson(Map<String, dynamic> json) {
    final address = json['address'] as Map<String, dynamic>? ?? {};
    final String rawDisplayName = json['display_name'] ?? '';

    // 1. Determine Title
    // Use 'name' if available, otherwise try 'road', else first part of display_name
    String title = json['name'] as String? ?? '';

    // Logic to prefer road name/house number if pure name is empty
    if (title.isEmpty) {
       if (address.containsKey('road')) {
         title = address['road'];
         // Address number often makes it more specific (Uber style)
         if (address.containsKey('house_number')) {
           title = "${address['house_number']} $title";
         }
       }
    }

    // If still empty, use the first distinct part of the display name
    if (title.isEmpty) {
       title = rawDisplayName.split(',')[0].trim();
    }

    // 2. Determine Subtitle (City, State, Country context)
    List<String> parts = [];

    // Neighborhood/Suburb
    if (address['suburb'] != null && address['suburb'] != title) {
        parts.add(address['suburb']);
    }

    // City part
    String? city = address['city'] ?? address['town'] ?? address['village'] ?? address['hamlet'];
    // Avoid repeating city if it's already in the title (rare but possible) or subtitle
    if (city != null && city != title && !parts.contains(city)) {
        parts.add(city);
    }

    // State/Region - keep it short if possible?? usually just state name
    if (address['state'] != null && address['state'] != city) {
        parts.add(address['state']);
    }

    // Join parts.
    String subtitle = parts.join(', ');

    // Fallback if construction failed
    if (subtitle.isEmpty) {
      int firstComma = rawDisplayName.indexOf(',');
      if (firstComma != -1) {
        subtitle = rawDisplayName.substring(firstComma + 1).trim();
      }
    }

    return LocationSuggestion(
      displayName: rawDisplayName,
      title: title,
      subtitle: subtitle,
      city: city, // expose city specifically for the text field logic
      lat: double.tryParse(json['lat'] ?? '0') ?? 0,
      lon: double.tryParse(json['lon'] ?? '0') ?? 0,
    );
  }
}

class LocationService {
  static const String _baseUrl = 'https://nominatim.openstreetmap.org/search';

  Future<List<LocationSuggestion>> getSuggestions(String query) async {
    if (query.length < 3) return [];

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl?q=$query&format=json&addressdetails=1&limit=5'),
        headers: {
          // User-Agent is required by Nominatim
          'User-Agent': 'PantaGo_Recycling_App/1.0',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) => LocationSuggestion.fromJson(item)).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching location suggestions: $e');
      return [];
    }
  }
}
