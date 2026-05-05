import 'package:isar/isar.dart';

import '../../../../core/providers/isar_provider.dart';
import '../models/note_entity.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NotesRepository {
  NotesRepository(this._isar);

  final Isar _isar;

  Future<void> seedDemoDataIfEmpty() async {
    final count = await _isar.noteEntitys.count();
    if (count > 0) return;

    final now = DateTime.now();
    final a = NoteEntity.newEmpty()
      ..title = 'Welcome to Mexy Note'
      ..content =
          'This app works fully offline.\n\n- Tap + to add a note\n- Swipe left to delete\n- Pin notes to keep them on top\n- Lock notes with a 4-digit PIN'
          'This app works fully offline.\n\n- Tap + to add a note\n- Swipe left to delete\n- Pin notes to keep them on top\n- Switch between Notes and Tasks'
      ..createdAt = now
      ..updatedAt = now
      ..isPinned = true;

    final b = NoteEntity.newEmpty()
      ..title = 'Quick task idea'
      ..content = 'Convert a note into a task (coming next).'
      ..createdAt = now
      ..updatedAt = now
      ..isTask = true
      ..isTaskCompleted = false;

    final c = NoteEntity.newEmpty()
      ..title = 'Reminder idea'
      ..content = 'Add a reminder and get a local notification (coming next).'
      ..createdAt = now
      ..updatedAt = now;

    await _isar.writeTxn(() async {
      await _isar.noteEntitys.putAll([a, b, c]);
    });
  }

  Future<NoteEntity> createEmpty() async {
    final note = NoteEntity.newEmpty();
    await upsert(note);
    return note;
  }

  Stream<List<NoteEntity>> watchAll() {
    return _isar.noteEntitys
        .where()
        .sortByIsPinnedDesc()
        .thenByUpdatedAtDesc()
        .watch(fireImmediately: true);
  }

  Future<NoteEntity?> getByUid(String uid) async {
    return _isar.noteEntitys.filter().uidEqualTo(uid).findFirst();
  }

  Future<void> upsert(NoteEntity note) async {
    await _isar.writeTxn(() async {
      await _isar.noteEntitys.put(note);
    });
  }

  Future<void> deleteByUid(String uid) async {
    await _isar.writeTxn(() async {
      final existing =
          await _isar.noteEntitys.filter().uidEqualTo(uid).findFirst();
      if (existing != null) {
        await _isar.noteEntitys.delete(existing.isarId);
      }
    });
  }
}

final notesRepositoryProvider = FutureProvider<NotesRepository>((ref) async {
  final isar = await ref.watch(isarProvider.future);
  return NotesRepository(isar);
});

