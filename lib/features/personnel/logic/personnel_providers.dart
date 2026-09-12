import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/hive_init.dart';
import '../data/models/personnel.dart';

final personnelProvider = StreamProvider<List<PersonnelEntry>>((ref) async* {
  final box = HiveInit.personnel;
  List<PersonnelEntry> getList() =>
      box.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  yield getList();
  yield* box.watch().map((_) => getList());
});

final personnelByRoleProvider =
    Provider.family<List<PersonnelEntry>, PersonnelRole>((ref, role) {
  final all = ref.watch(personnelProvider).value ?? [];
  return all.where((e) => e.role == role).toList();
});

class PersonnelService {
  Future<PersonnelEntry> add({
    required PersonnelRole role,
    required String name,
    required String phone,
    String location = '',
    String extra = '',
  }) async {
    if (name.trim().isEmpty) throw Exception('الاسم مطلوب');
    if (phone.trim().isEmpty) throw Exception('الهاتف مطلوب');
    final p = PersonnelEntry(
        role: role, name: name.trim(), phone: phone.trim(),
        location: location.trim(), extra: extra.trim());
    await HiveInit.personnel.put(p.id, p);
    return p;
  }

  Future<void> update(PersonnelEntry p,
      {required String name, required String phone, String? location, String? extra}) async {
    p.name = name.trim();
    p.phone = phone.trim();
    if (location != null) p.location = location.trim();
    if (extra != null) p.extra = extra.trim();
    await p.save();
  }

  Future<void> delete(PersonnelEntry p) async => await p.delete();
}

final personnelServiceProvider = Provider((ref) => PersonnelService());
