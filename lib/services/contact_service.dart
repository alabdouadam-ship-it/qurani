import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ContactService {
  static const String _remoteUrl = 'https://qurani.info/data/about-qurani/contact.json';
  static const String _cacheKey = 'contact_info_cache';
  static const String _cacheTimestampKey = 'contact_info_timestamp';
  static const int _cacheDurationDays = 7;

  /// Get contact information with fallback strategy:
  /// 1. Try remote (if cache expired and internet available)
  /// 2. Use cached data (even if expired)
  /// 3. Use bundled asset as last resort
  static Future<Map<String, dynamic>> getContactInfo() async {
    try {
      // Check if cache is expired
      final isExpired = await _isCacheExpired();
      
      if (isExpired) {
        // Try to fetch from remote
        final remoteData = await _fetchRemote();
        if (remoteData != null) {
          await _saveCache(remoteData);
          return remoteData;
        }
      }
      
      // Try to use cached data (even if expired, as fallback)
      final cachedData = await _loadCached();
      if (cachedData != null) {
        return cachedData;
      }
      
      // Last resort: use bundled asset
      return await _loadFallback();
    } catch (_) {
      // Silent fallback to bundled asset on any error
      try {
        return await _loadFallback();
      } catch (_) {
        // Return empty map if everything fails
        return {};
      }
    }
  }

  static Future<bool> _isCacheExpired() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final timestamp = prefs.getInt(_cacheTimestampKey);
      if (timestamp == null) return true;
      
      final cacheDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();
      final difference = now.difference(cacheDate);
      
      return difference.inDays >= _cacheDurationDays;
    } catch (_) {
      return true;
    }
  }

  static Future<Map<String, dynamic>?> _fetchRemote() async {
    try {
      final response = await http.get(
        Uri.parse(_remoteUrl),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return data;
      }
      return null;
    } catch (_) {
      // Silent failure - will use cache or fallback
      return null;
    }
  }

  static Future<Map<String, dynamic>?> _loadCached() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final cached = prefs.getString(_cacheKey);
      if (cached == null) return null;
      
      return json.decode(cached) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _saveCache(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setString(_cacheKey, json.encode(data));
      await prefs.setInt(_cacheTimestampKey, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {
      // Silent failure - caching is optional
    }
  }

  static Future<Map<String, dynamic>> _loadFallback() async {
    final txt = await rootBundle.loadString('public/contact.json');
    return json.decode(txt) as Map<String, dynamic>;
  }
}
