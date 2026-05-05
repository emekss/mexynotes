import 'dart:math';

import 'package:isar/isar.dart';

part 'note_entity.g.dart';

@embedded
class ChecklistItem {
  ChecklistItem({this.text = '', this.isDone = false});

  String text;
  bool isDone;
}

@embedded
class NoteAttachment {
  NoteAttachment({
    this.id = '',
    this.name = '',
    this.path = '',
    this.sizeBytes = 0,
    this.addedAtMs = 0,
    this.mimeType,
  });

  /// Random id for stable identity/removal.
  String id;

  /// Original file name.
  String name;

  /// Stored local path (copied into app storage).
  String path;

  String? mimeType;

  int sizeBytes;

  /// Unix epoch milliseconds.
  int addedAtMs;
}

@collection
class NoteEntity {
  NoteEntity({
    required this.uid,
    required this.createdAt,
    required this.updatedAt,
    this.title = '',
    this.content = '',
    this.checklist = const [],
    this.attachments = const [],
    this.isPinned = false,
    this.isTask = false,
    this.isTaskCompleted = false,
    this.reminderAt,
  });

  /// Internal Isar id.
  Id isarId = Isar.autoIncrement;

  /// External stable id (used by UI/routes).
  @Index(unique: true)
  late String uid;

  @Index(type: IndexType.value)
  String title = '';

  String content = '';

  List<ChecklistItem> checklist = const [];

  List<NoteAttachment> attachments = const [];

  @Index()
  late DateTime createdAt;

  @Index()
  late DateTime updatedAt;

  @Index()
  bool isPinned = false;

  // --- Task/Reminder extensions.
  @Index()
  bool isTask = false;

  @Index()
  bool isTaskCompleted = false;

  @Index()
  DateTime? reminderAt;

  static NoteEntity newEmpty() {
    final now = DateTime.now();
    return NoteEntity(
      uid: _makeUid(),
      createdAt: now,
      updatedAt: now,
    );
  }

  static String _makeUid() {
    final rand = Random.secure().nextInt(1 << 32);
    return '${DateTime.now().microsecondsSinceEpoch}-$rand';
  }
}

