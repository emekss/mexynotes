import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../../features/notes/data/models/note_entity.dart';

class IsarDb {
  static Future<Isar> open() async {
    final dir = await getApplicationDocumentsDirectory();
    return Isar.open(
      [
        NoteEntitySchema,
      ],
      directory: dir.path,
      inspector: true,
    );
  }
}

