import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/note_entity.dart';
import '../../data/repositories/notes_repository.dart';

enum HomeFilter { all, notesOnly, tasksOnly }

final homeFilterProvider =
    StateProvider<HomeFilter>((ref) => HomeFilter.notesOnly);
final homeSearchQueryProvider = StateProvider<String>((ref) => '');

final notesStreamProvider = StreamProvider<List<NoteEntity>>((ref) async* {
  final repo = await ref.watch(notesRepositoryProvider.future);
  await repo.seedDemoDataIfEmpty();
  yield* repo.watchAll();
});

final filteredNotesProvider = Provider<AsyncValue<List<NoteEntity>>>((ref) {
  final notesAsync = ref.watch(notesStreamProvider);
  final filter = ref.watch(homeFilterProvider);
  final q = ref.watch(homeSearchQueryProvider).trim().toLowerCase();

  return notesAsync.whenData((notes) {
    Iterable<NoteEntity> out = notes;

    switch (filter) {
      case HomeFilter.all:
        break;
      case HomeFilter.notesOnly:
        out = out.where((n) => !n.isTask);
        break;
      case HomeFilter.tasksOnly:
        out = out.where((n) => n.isTask);
        break;
    }

    if (q.isNotEmpty) {
      out = out.where(
        (n) =>
            n.title.toLowerCase().contains(q) ||
            n.content.toLowerCase().contains(q),
      );
    }

    return out.toList(growable: false);
  });
});

