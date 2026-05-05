import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/notes/presentation/screens/home_screen.dart';
import '../../features/notes/presentation/screens/note_editor_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
        routes: [
          GoRoute(
            path: 'note/:id',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return NoteEditorScreen(noteId: id);
            },
          ),
        ],
      ),
    ],
  );
});

