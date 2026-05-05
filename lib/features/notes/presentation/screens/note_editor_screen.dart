import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../core/services/notifications_service.dart';
import '../../data/models/note_entity.dart';
import '../../data/repositories/notes_repository.dart';

// We intentionally show dialogs during async flows and guard with `mounted`
// immediately after awaiting them.
// ignore_for_file: use_build_context_synchronously

class NoteEditorScreen extends ConsumerStatefulWidget {
  const NoteEditorScreen({super.key, required this.noteId});

  final String noteId;

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  NoteEntity? _note;
  bool _loading = true;

  late final TextEditingController _titleCtrl;
  late final TextEditingController _contentCtrl;
  DateTime _lastSavedAt = DateTime.fromMillisecondsSinceEpoch(0);
  Future<void>? _pendingSave;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    _contentCtrl = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _disposed = true;
    _titleCtrl.removeListener(_scheduleAutosave);
    _contentCtrl.removeListener(_scheduleAutosave);
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = await ref.read(notesRepositoryProvider.future);
    final note = await repo.getByUid(widget.noteId);
    if (!mounted) return;

    if (note == null) {
      setState(() {
        _note = null;
        _loading = false;
      });
      return;
    }

    _note = note;
    _titleCtrl.text = note.title;
    _contentCtrl.text = note.content;

    _titleCtrl.addListener(_scheduleAutosave);
    _contentCtrl.addListener(_scheduleAutosave);

    setState(() => _loading = false);
  }

  void _scheduleAutosave() {
    final note = _note;
    if (note == null) return;

    final now = DateTime.now();
    if (now.difference(_lastSavedAt).inMilliseconds < 350) return;

    _pendingSave ??= Future<void>.delayed(const Duration(milliseconds: 450))
        .then((_) async {
          _pendingSave = null;
          if (_disposed) return;
          await _saveNow();
        });
  }

  Future<void> _saveNow() async {
    final note = _note;
    if (note == null) return;
    if (_disposed) return;

    final repo = await ref.read(notesRepositoryProvider.future);
    note
      ..title = _titleCtrl.text
      ..content = _contentCtrl.text
      ..updatedAt = DateTime.now();

    await repo.upsert(note);
    _lastSavedAt = DateTime.now();
  }

  Future<void> _togglePinned() async {
    final note = _note;
    if (note == null) return;

    final repo = await ref.read(notesRepositoryProvider.future);
    note
      ..isPinned = !note.isPinned
      ..updatedAt = DateTime.now();
    await repo.upsert(note);
    setState(() {});
  }

  Future<void> _toggleTaskMode() async {
    final note = _note;
    if (note == null) return;

    final repo = await ref.read(notesRepositoryProvider.future);
    note
      ..isTask = !note.isTask
      ..updatedAt = DateTime.now();
    if (!note.isTask) {
      note
        ..isTaskCompleted = false
        ..checklist = const [];
    }
    await repo.upsert(note);
    setState(() {});
  }

  Future<void> _addChecklistItem() async {
    final note = _note;
    if (note == null) return;
    final text = await _promptText(context, title: 'Checklist item');
    if (text == null) return;

    final repo = await ref.read(notesRepositoryProvider.future);
    note
      ..checklist = [...note.checklist, ChecklistItem(text: text)]
      ..updatedAt = DateTime.now();
    await repo.upsert(note);
    setState(() {});
  }

  Future<void> _setReminder() async {
    final note = _note;
    if (note == null) return;

    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      initialDate: note.reminderAt ?? DateTime.now(),
    );
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(note.reminderAt ?? DateTime.now()),
    );
    if (time == null) return;

    final when = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    final repo = await ref.read(notesRepositoryProvider.future);
    note
      ..reminderAt = when
      ..updatedAt = DateTime.now();
    await repo.upsert(note);

    await NotificationsService.instance.scheduleReminder(
      noteUid: note.uid,
      when: when,
      title: note.title,
    );
    setState(() {});
  }

  Future<void> _clearReminder() async {
    final note = _note;
    if (note == null) return;

    final repo = await ref.read(notesRepositoryProvider.future);
    note
      ..reminderAt = null
      ..updatedAt = DateTime.now();
    await repo.upsert(note);
    await NotificationsService.instance.cancelReminder(note.uid);
    setState(() {});
  }

  Future<void> _attachFiles() async {
    final note = _note;
    if (note == null) return;

    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;

    final appDir = await getApplicationDocumentsDirectory();
    final baseDir = Directory(p.join(appDir.path, 'attachments', note.uid));
    if (!await baseDir.exists()) {
      await baseDir.create(recursive: true);
    }

    final nextAttachments = [...note.attachments];

    for (final f in result.files) {
      final srcPath = f.path;
      if (srcPath == null) continue;

      final id = _makeAttachmentId();
      final ext = p.extension(f.name);
      final safeExt = ext.isEmpty ? '' : ext;
      final dstPath = p.join(baseDir.path, '$id$safeExt');

      await File(srcPath).copy(dstPath);

      nextAttachments.add(
        NoteAttachment(
          id: id,
          name: f.name,
          path: dstPath,
          sizeBytes: f.size,
          addedAtMs: DateTime.now().millisecondsSinceEpoch,
          mimeType: lookupMimeType(dstPath),
        ),
      );
    }

    final repo = await ref.read(notesRepositoryProvider.future);
    note
      ..attachments = nextAttachments
      ..updatedAt = DateTime.now();
    await repo.upsert(note);
    if (!_disposed) setState(() {});
  }

  Future<void> _removeAttachment(String attachmentId) async {
    final note = _note;
    if (note == null) return;

    final idx = note.attachments.indexWhere((a) => a.id == attachmentId);
    if (idx < 0) return;

    final repo = await ref.read(notesRepositoryProvider.future);
    final next = [...note.attachments]..removeAt(idx);
    note
      ..attachments = next
      ..updatedAt = DateTime.now();
    await repo.upsert(note);
    if (!_disposed) setState(() {});
  }

  Future<void> _openAttachment(NoteAttachment a) async {
    await OpenFilex.open(a.path);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator.adaptive()),
      );
    }

    final note = _note;
    if (note == null) {
      return const Scaffold(body: Center(child: Text('Note not found')));
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Note', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: 'Attach files',
            onPressed: _attachFiles,
            icon: const Icon(Icons.attach_file),
          ),
          IconButton(
            tooltip: note.isTask ? 'Disable task mode' : 'Enable task mode',
            onPressed: _toggleTaskMode,
            icon: Icon(
              note.isTask ? Icons.checklist : Icons.checklist_outlined,
            ),
          ),
          IconButton(
            tooltip: note.isPinned ? 'Unpin' : 'Pin',
            onPressed: _togglePinned,
            icon: Icon(
              note.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
            ),
          ),
          IconButton(
            tooltip: note.reminderAt == null
                ? 'Add reminder'
                : 'Clear reminder',
            onPressed: note.reminderAt == null ? _setReminder : _clearReminder,
            icon: Icon(
              note.reminderAt == null
                  ? Icons.notifications_outlined
                  : Icons.notifications_active_outlined,
            ),
          ),
          const SizedBox(width: 4),
        ],
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
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _GlassField(
                  child: TextField(
                    controller: _titleCtrl,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Title',
                      hintStyle: TextStyle(color: Color(0xAAFFFFFF)),
                      border: InputBorder.none,
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                ),
                const SizedBox(height: 12),
                if (note.attachments.isNotEmpty) ...[
                  _AttachmentsSection(
                    attachments: note.attachments,
                    onOpen: _openAttachment,
                    onRemove: _removeAttachment,
                  ),
                  const SizedBox(height: 12),
                ],
                if (note.isTask) ...[
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Checklist',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Add item',
                        onPressed: _addChecklistItem,
                        icon: const Icon(Icons.add, color: Colors.white),
                      ),
                    ],
                  ),
                  if (note.checklist.isEmpty)
                    _EmptyChecklistCard(onAdd: _addChecklistItem)
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: note.checklist.length,
                        itemBuilder: (context, i) {
                          final item = note.checklist[i];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.10),
                              ),
                            ),
                            child: CheckboxListTile(
                              value: item.isDone,
                              controlAffinity: ListTileControlAffinity.leading,
                              title: Text(
                                item.text,
                                style: const TextStyle(color: Colors.white),
                              ),
                              onChanged: (v) async {
                                if (_disposed) return;
                                final repo = await ref.read(
                                  notesRepositoryProvider.future,
                                );
                                final next = [...note.checklist];
                                next[i] = ChecklistItem(
                                  text: item.text,
                                  isDone: v ?? false,
                                );
                                note
                                  ..checklist = next
                                  ..isTaskCompleted = next.isNotEmpty &&
                                      next.every((e) => e.isDone)
                                  ..updatedAt = DateTime.now();
                                await repo.upsert(note);
                                if (!_disposed) setState(() {});
                              },
                              activeColor: const Color(0xFF7C3AED),
                              checkColor: Colors.white,
                              side: const BorderSide(color: Colors.white70),
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 12),
                ],
                Expanded(
                  child: _GlassField(
                    child: TextField(
                      controller: _contentCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Start writing...',
                        hintStyle: TextStyle(color: Color(0xAAFFFFFF)),
                        border: InputBorder.none,
                      ),
                      expands: true,
                      maxLines: null,
                      minLines: null,
                      keyboardType: TextInputType.multiline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassField extends StatelessWidget {
  const _GlassField({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: child,
    );
  }
}

class _EmptyChecklistCard extends StatelessWidget {
  const _EmptyChecklistCard({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.checklist_outlined,
            size: 44,
            color: Colors.white.withValues(alpha: 0.85),
          ),
          const SizedBox(height: 10),
          const Text(
            'No checklist items yet.',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap + to add your first item.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.70)),
          ),
          const SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
            ),
            onPressed: onAdd,
            child: const Text('Add item'),
          ),
        ],
      ),
    );
  }
}

Future<String?> _promptText(
  BuildContext context, {
  required String title,
}) async {
  final ctrl = TextEditingController();
  final formKey = GlobalKey<FormState>();

  final result = await showDialog<String?>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Form(
        key: formKey,
        child: TextFormField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Text'),
          validator: (v) => (v ?? '').trim().isEmpty ? 'Enter text' : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!(formKey.currentState?.validate() ?? false)) return;
            Navigator.of(context).pop(ctrl.text.trim());
          },
          child: const Text('Add'),
        ),
      ],
    ),
  );

  WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose());
  return result;
}

String _makeAttachmentId() {
  final micros = DateTime.now().microsecondsSinceEpoch;
  return micros.toString();
}

class _AttachmentsSection extends StatelessWidget {
  const _AttachmentsSection({
    required this.attachments,
    required this.onOpen,
    required this.onRemove,
  });

  final List<NoteAttachment> attachments;
  final Future<void> Function(NoteAttachment) onOpen;
  final Future<void> Function(String attachmentId) onRemove;

  @override
  Widget build(BuildContext context) {
    return _GlassField(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Attachments',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final a in attachments)
                _AttachmentTile(
                  attachment: a,
                  onOpen: () => onOpen(a),
                  onRemove: () => onRemove(a.id),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({
    required this.attachment,
    required this.onOpen,
    required this.onRemove,
  });

  final NoteAttachment attachment;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final mime = (attachment.mimeType ?? '').toLowerCase();
    final isImage = mime.startsWith('image/');

    return SizedBox(
      width: 120,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onOpen,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(14),
                    ),
                    child: SizedBox(
                      height: 78,
                      width: double.infinity,
                      child: isImage
                          ? Image.file(
                              File(attachment.path),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _fileIcon(Icons.image_outlined),
                            )
                          : _fileIcon(_iconForMime(mime)),
                    ),
                  ),
                  Positioned(
                    right: 4,
                    top: 4,
                    child: InkWell(
                      onTap: onRemove,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Text(
                  attachment.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fileIcon(IconData icon) {
    return Container(
      color: Colors.white.withValues(alpha: 0.03),
      child: Center(
        child: Icon(icon, color: Colors.white.withValues(alpha: 0.85), size: 28),
      ),
    );
  }
}

IconData _iconForMime(String mime) {
  if (mime.startsWith('video/')) return Icons.videocam_outlined;
  if (mime == 'application/pdf') return Icons.picture_as_pdf_outlined;
  if (mime.startsWith('audio/')) return Icons.audiotrack_outlined;
  return Icons.insert_drive_file_outlined;
}
