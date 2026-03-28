import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import '../models/category.dart';
import '../services/database_service.dart';

final categoriesProvider = StreamProvider<List<Category>>((ref) async* {
  final isar = await DatabaseService.instance;
  yield* isar.categorys
      .filter()
      .isActiveEqualTo(true)
      .sortBySortOrder()
      .watch(fireImmediately: true);
});
