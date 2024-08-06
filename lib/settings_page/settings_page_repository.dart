import 'package:notel/infrastructure/db.dart';

class SettingsPageRepository {
  static Future<List<Map<String, Object?>>> getNotes() async {
    return await Db.instance.query(Db.noteTable);
  }
}
