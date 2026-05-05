import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';

import '../services/isar_db.dart';

final isarProvider = FutureProvider<Isar>((ref) async {
  final isar = await IsarDb.open();
  ref.onDispose(isar.close);
  return isar;
});

