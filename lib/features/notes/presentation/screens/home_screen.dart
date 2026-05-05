import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/note_entity.dart';
import '../../data/repositories/notes_repository.dart';
import '../providers/notes_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(filteredNotesProvider);
    final filter = ref.watch(homeFilterProvider);
    final isNotes = filter != HomeFilter.tasksOnly;
    const onBg = Colors.white;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Mexy Note',
          style: const TextStyle(color: onBg),
        ),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1A0B2E),
              Color(0xFF12091E),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: _SearchField(
                  onChanged: (v) =>
                      ref.read(homeSearchQueryProvider.notifier).state = v,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _NotesTasksToggle(
                  isNotesSelected: isNotes,
                  onSelectNotes: () => ref
                      .read(homeFilterProvider.notifier)
                      .state = HomeFilter.notesOnly,
                  onSelectTasks: () => ref
                      .read(homeFilterProvider.notifier)
                      .state = HomeFilter.tasksOnly,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: notesAsync.when(
                  data: (notes) {
                    if (notes.isEmpty) {
                      return const _EmptyState();
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: notes.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final n = notes[index];
                        return _NoteCard(
                          note: n,
                          onTap: () => context.push('/note/${n.uid}'),
                          onDelete: () async {
                            final repo = await ref.read(
                              notesRepositoryProvider.future,
                            );
                            await repo.deleteByUid(n.uid);
                          },
                          onTogglePinned: () async {
                            final repo = await ref.read(
                              notesRepositoryProvider.future,
                            );
                            n
                              ..isPinned = !n.isPinned
                              ..updatedAt = DateTime.now();
                            await repo.upsert(n);
                          },
                        );
                      },
                    );
                  },
                  error: (e, _) => Center(
                    child: Text(
                      'Error: $e',
                    style: const TextStyle(color: onBg),
                    ),
                  ),
                  loading: () => const Center(
                    child: CircularProgressIndicator.adaptive(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF7C3AED),
        onPressed: () async {
          final repo = await ref.read(notesRepositoryProvider.future);
          final note = await repo.createEmpty();
          if (context.mounted) {
            context.push('/note/${note.uid}');
          }
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.note_alt_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            const SizedBox(height: 12),
            Text(
              'No notes yet',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurface),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap + to create your first note.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurface),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: TextField(
        onChanged: onChanged,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search, color: Colors.white),
          hintText: 'Search notes',
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.65)),
          filled: false,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}

class _NotesTasksToggle extends StatelessWidget {
  const _NotesTasksToggle({
    required this.isNotesSelected,
    required this.onSelectNotes,
    required this.onSelectTasks,
  });

  final bool isNotesSelected;
  final VoidCallback onSelectNotes;
  final VoidCallback onSelectTasks;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ToggleChip(
              selected: isNotesSelected,
              icon: Icons.note_outlined,
              label: 'Notes',
              onTap: onSelectNotes,
              textColor: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ToggleChip(
              selected: !isNotesSelected,
              icon: Icons.checklist_outlined,
              label: 'Tasks',
              onTap: onSelectTasks,
              textColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.textColor,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: selected ? Colors.white.withValues(alpha: 0.10) : null,
        ),
        child: Row(
          children: [
            Icon(icon, color: textColor, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Icon(
              selected ? Icons.check : Icons.circle_outlined,
              color: textColor.withValues(alpha: 0.85),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.note,
    required this.onTap,
    required this.onDelete,
    required this.onTogglePinned,
  });

  final NoteEntity note;
  final VoidCallback onTap;
  final Future<void> Function() onDelete;
  final Future<void> Function() onTogglePinned;

  @override
  Widget build(BuildContext context) {
    final title = note.title.trim().isEmpty ? '(No title)' : note.title;
    final subtitle =
        note.content.trim().isEmpty ? 'No content' : note.content.trim();
    final when = _formatTime(note.updatedAt);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 34,
              child: note.isPinned
                  ? Icon(
                      Icons.push_pin_outlined,
                      color: const Color(0xFFB892FF),
                      size: 22,
                    )
                  : const SizedBox.shrink(),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      if (note.isTask)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Icon(
                            note.isTaskCompleted
                                ? Icons.check_circle_outline
                                : Icons.radio_button_unchecked,
                            color: Colors.white.withValues(alpha: 0.85),
                            size: 18,
                          ),
                        ),
                      PopupMenuButton<_CardAction>(
                        icon: Icon(
                          Icons.more_vert,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                        onSelected: (a) async {
                          switch (a) {
                            case _CardAction.pin:
                              await onTogglePinned();
                              return;
                            case _CardAction.delete:
                              await onDelete();
                              return;
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: _CardAction.pin,
                            child: Text(note.isPinned ? 'Unpin' : 'Pin'),
                          ),
                          const PopupMenuItem(
                            value: _CardAction.delete,
                            child: Text('Delete'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.78),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    when,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _CardAction { pin, delete }

String _formatTime(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return 'Just now';
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '$h:$m';
}
