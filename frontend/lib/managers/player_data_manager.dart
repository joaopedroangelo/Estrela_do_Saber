import 'package:shared_preferences/shared_preferences.dart';

class PlayerPreferences {
  static const String _playerNameKey = 'playerName';
  static const String _playerGradeKey = 'playerGrade';
  static const String _parentEmailKey = 'parentEmail';
  static const String _playerInitialsKey = 'playerInitials';

  static Future<void> savePlayerData({
    required String name,
    required String grade,
    required String parentEmail,
    required String initials,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_playerNameKey, name);
    await prefs.setString(_playerGradeKey, grade);
    await prefs.setString(_parentEmailKey, parentEmail);
    await prefs.setString(_playerInitialsKey, initials);
  }

  static Future<Map<String, dynamic>> getPlayerData() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'name': prefs.getString(_playerNameKey) ?? '',
      'grade': prefs.getString(_playerGradeKey) ?? '',
      'parentEmail': prefs.getString(_parentEmailKey) ?? '',
      'initials': prefs.getString(_playerInitialsKey) ?? '🙂',
    };
  }

  static Future<void> clearPlayerData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_playerNameKey);
    await prefs.remove(_playerGradeKey);
    await prefs.remove(_parentEmailKey);
    await prefs.remove(_playerInitialsKey);
  }
}
