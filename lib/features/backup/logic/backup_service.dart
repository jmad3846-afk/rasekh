import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/database/hive_init.dart';
import '../../factory/data/models/product.dart';
import '../../factory/data/models/customer.dart';
import '../../factory/data/models/invoice.dart';
import '../../factory/data/models/stock_log.dart';
import '../../factory/data/models/price_tier.dart';
import '../../projects/data/models/project.dart';
import '../../projects/data/models/procedure.dart';
import '../../finance/data/models/transaction.dart';
import '../../personnel/data/models/personnel.dart';
import '../../projects/data/models/site_materials.dart';
import '../../projects/data/models/site_procedure.dart';

class BackupService {
  static const String backupVersion = '6.0';
  static Map<String,dynamic> _buildJson() {
    final now = DateTime.now();
    return {
      'metadata': {'version': backupVersion,'createdAt': now.toIso8601String(),'app': 'Factory_Managment','counts': {'products': HiveInit.products.length,'customers': HiveInit.customers.length,'invoices': HiveInit.invoices.length,'projects': HiveInit.projects.length,'procedures': HiveInit.procedures.length,'transactions': HiveInit.transactions.length,'personnel': HiveInit.personnel.length,'requiredMaterials': HiveInit.requiredMaterials.length,'dailyLogs': HiveInit.dailyLogs.length,'siteProcedures': HiveInit.siteProcedures.length,'stockLogs': HiveInit.stockLogs.length,'priceTiers': HiveInit.priceTiers.length}},
      'products': HiveInit.products.values.map((e)=> e.toJson()).toList(),
      'customers': HiveInit.customers.values.map((e)=> e.toJson()).toList(),
      'invoices': HiveInit.invoices.values.map((e)=> e.toJson()).toList(),
      'projects': HiveInit.projects.values.map((e)=> e.toJson()).toList(),
      'procedures': HiveInit.procedures.values.map((e)=> e.toJson()).toList(),
      'transactions': HiveInit.transactions.values.map((e)=> e.toJson()).toList(),
      'personnel': HiveInit.personnel.values.map((e)=> e.toJson()).toList(),
      'requiredMaterials': HiveInit.requiredMaterials.values.map((e)=> e.toJson()).toList(),
      'dailyLogs': HiveInit.dailyLogs.values.map((e)=> e.toJson()).toList(),
      'siteProcedures': HiveInit.siteProcedures.values.map((e)=> e.toJson()).toList(),
      'stockLogs': HiveInit.stockLogs.values.map((e)=> e.toJson()).toList(),
      'priceTiers': HiveInit.priceTiers.values.map((e)=> e.toJson()).toList(),
    };
  }
  static String _timestamp() { final n=DateTime.now(); String two(int v)=> v.toString().padLeft(2,'0'); return '${n.year}-${two(n.month)}-${two(n.day)}_${two(n.hour)}${two(n.minute)}';}
  static String _checksum(String s)=> sha256.convert(utf8.encode(s)).toString();

  /// Reliable export:
  /// 1. Build .zip inside getTemporaryDirectory() (avoids Android scoped-storage POSIX issues).
  /// 2. Hand bytes to FilePicker.saveFile (SAF) so user picks SD/USB safely.
  /// 3. Fallback to legacy getDirectoryPath + direct write.
  static Future<String?> exportBackup({bool asZip=true}) async {
    final data=_buildJson();
    final jsonStr=const JsonEncoder.withIndent('  ').convert(data);
    final checksum=_checksum(jsonStr);
    final fileName='Factory_Backup_${_timestamp()}';
    final tmpDir = await getTemporaryDirectory();

    if(asZip){
      final archive=Archive();
      archive.addFile(ArchiveFile('data.json', jsonStr.length, utf8.encode(jsonStr)));
      archive.addFile(ArchiveFile('checksum.txt', checksum.length, utf8.encode(checksum)));
      archive.addFile(ArchiveFile('metadata.txt', 200, utf8.encode('Version:$backupVersion\nCreated:${DateTime.now().toIso8601String()}\nChecksum:$checksum')));
      final allPaths=<String>{...HiveInit.projects.values.expand((p)=> p.photoPaths)};
      for(final path in allPaths){ try{ final f=File(path); if(await f.exists()){ final bytes=await f.readAsBytes(); final name=path.split(Platform.pathSeparator).last; archive.addFile(ArchiveFile('images/$name', bytes.length, bytes));}}catch(_){}
      }
      final encoded = ZipEncoder().encode(archive);
      if (encoded == null) throw Exception('فشل إنشاء ZIP');
      final zipBytes=Uint8List.fromList(encoded);
      // Stage in temp first.
      final staged = File('${tmpDir.path}/$fileName.zip');
      await staged.writeAsBytes(zipBytes, flush: true);

      // Preferred: SAF save dialog with bytes (works on Android 11+ scoped storage).
      try {
        final savedPath = await FilePicker.platform.saveFile(
          dialogTitle: 'حفظ النسخة الاحتياطية',
          fileName: '$fileName.zip',
          bytes: zipBytes,
        );
        if (savedPath != null) return savedPath;
        // User cancelled save dialog → keep staged temp path as fallback result.
      } catch (_) {
        // saveFile not supported on this platform → legacy fallback below.
      }
      try {
        String? dir=await FilePicker.platform.getDirectoryPath(dialogTitle:'اختر مكان حفظ النسخة (SD/USB)');
        if(dir==null) return staged.path;
        final out=File('$dir/$fileName.zip');
        await out.writeAsBytes(zipBytes, flush: true);
        return out.path;
      } catch (_) {
        return staged.path;
      }
    } else {
      final staged = File('${tmpDir.path}/$fileName.json');
      await staged.writeAsString(jsonStr, flush: true);
      final bytes = Uint8List.fromList(utf8.encode(jsonStr));
      try {
        final savedPath = await FilePicker.platform.saveFile(
          dialogTitle: 'حفظ النسخة الاحتياطية',
          fileName: '$fileName.json',
          bytes: bytes,
        );
        if (savedPath != null) {
          return savedPath;
        }
      } catch (_) {}
      String? dir=await FilePicker.platform.getDirectoryPath(dialogTitle:'اختر مكان حفظ النسخة (SD/USB)');
      if(dir==null) return staged.path;
      final out=File('$dir/$fileName.json');
      await out.writeAsString(jsonStr);
      await File('$dir/$fileName.checksum.txt').writeAsString(checksum);
      return out.path;
    }
  }

  static Future<RestoreResult> restoreBackup() async {
    final res=await FilePicker.platform.pickFiles(type:FileType.any, allowMultiple:false, withData: true);
    if(res==null||res.files.isEmpty) return RestoreResult.cancelled;
    final picked = res.files.single;
    Map<String,dynamic> data;
    Map<String,String> restoredImagePaths = {};
    if(picked.name.endsWith('.zip') || (picked.path ?? '').endsWith('.zip')){
      Uint8List bytes;
      if (picked.bytes != null) {
        bytes = picked.bytes!;
      } else if (picked.path != null) {
        bytes = await File(picked.path!).readAsBytes();
      } else {
        throw Exception('تعذر قراءة ملف النسخة');
      }
      // Validate zip integrity before touching current data.
      Archive archive;
      try {
        archive = ZipDecoder().decodeBytes(bytes);
      } catch (e) {
        throw Exception('ملف ZIP تالف: $e');
      }
      final dataFiles = archive.files.where((f)=> f.name=='data.json').toList();
      if(dataFiles.isEmpty) throw Exception('Invalid backup: data.json missing داخل ZIP');
      final dataFile=dataFiles.first;
      final jsonStr=utf8.decode(dataFile.content as List<int>);
      final checksumFile=archive.files.where((f)=> f.name=='checksum.txt').firstOrNull;
      if(checksumFile!=null){
        final expected=utf8.decode(checksumFile.content as List<int>).trim();
        final actual=_checksum(jsonStr);
        if(expected!=actual) throw Exception('فشل التحقق: checksum غير متطابق - الملف تالف');
      }
      try {
        data=jsonDecode(jsonStr) as Map<String,dynamic>;
      } catch (e) {
        throw Exception('data.json غير صالح: $e');
      }
      // Schema version check.
      final meta = data['metadata'] as Map<String,dynamic>?;
      if (meta == null || meta['version'] == null) {
        throw Exception('نسخة غير صالحة: metadata.version مفقود');
      }
      // Validate BEFORE clearing.
      _validate(data);
      // Restore images into app's canonical project_images/ dir and remap paths.
      final appDir=await getApplicationDocumentsDirectory();
      final imgDir=Directory('${appDir.path}/project_images');
      if(!await imgDir.exists()) await imgDir.create(recursive:true);
      for(final f in archive.files.where((e)=> e.name.startsWith('images/'))){
        final baseName=f.name.split('/').last;
        if (baseName.isEmpty) continue;
        final out=File('${imgDir.path}/$baseName');
        await out.writeAsBytes(f.content as List<int>, flush: true);
        restoredImagePaths[baseName] = out.path;
      }
    } else {
      String jsonStr;
      if (picked.bytes != null) {
        jsonStr = utf8.decode(picked.bytes!);
      } else if (picked.path != null) {
        jsonStr = await File(picked.path!).readAsString();
      } else {
        throw Exception('تعذر قراءة ملف النسخة');
      }
      try {
        data=jsonDecode(jsonStr) as Map<String,dynamic>;
      } catch (e) {
        throw Exception('ملف JSON غير صالح: $e');
      }
      _validate(data);
    }
    await _clearAll();
    await _restore(data, restoredImagePaths: restoredImagePaths);
    return RestoreResult.success;
  }

  static void _validate(Map<String,dynamic> d){
    const req=['products','customers','invoices','projects','procedures','transactions','metadata'];
    for(final k in req) if(!d.containsKey(k)) throw Exception('Invalid backup: missing $k');
    // Version check (v1 backups lack new keys — default them to []).
    for (final k in ['personnel','requiredMaterials','dailyLogs','siteProcedures','stockLogs','priceTiers']) {
      d.putIfAbsent(k, ()=> []);
    }
    try {
      final meta = Map<String,dynamic>.from(d['metadata'] as Map);
      final v = meta['version']?.toString() ?? '';
      if (v.isNotEmpty && v != backupVersion && !v.startsWith('1.') && !v.startsWith('2.') && !v.startsWith('3.') && !v.startsWith('4.') && !v.startsWith('5.') && !v.startsWith('6.')) {
        throw Exception('إصدار نسخة غير مدعوم: $v (المدعوم $backupVersion)');
      }
    } catch (e) {
      if (e.toString().contains('غير مدعوم')) rethrow;
    }
    final cIds=(d['customers'] as List).map((e)=> (e as Map)['id']).toSet();
    for(final inv in d['invoices'] as List) {
      final m = Map<String,dynamic>.from(inv as Map);
      if(!cIds.contains(m['customerId'])) throw Exception('FK violation: invoice ${m['id']}');
    }
    final pIds=(d['projects'] as List).map((e)=> (e as Map)['id']).toSet();
    for(final pr in d['procedures'] as List) {
      final m = Map<String,dynamic>.from(pr as Map);
      if(!pIds.contains(m['projectId'])) throw Exception('FK violation: procedure ${m['id']}');
    }
  }
  static Future<void> _clearAll() async { await HiveInit.products.clear(); await HiveInit.customers.clear(); await HiveInit.invoices.clear(); await HiveInit.projects.clear(); await HiveInit.procedures.clear(); await HiveInit.transactions.clear(); await HiveInit.personnel.clear(); await HiveInit.requiredMaterials.clear(); await HiveInit.dailyLogs.clear(); await HiveInit.siteProcedures.clear(); await HiveInit.stockLogs.clear(); await HiveInit.priceTiers.clear();}
  static Future<void> _restore(Map<String,dynamic> d, {Map<String,String> restoredImagePaths = const {}}) async {
    String _remapPhoto(String old) {
      if (restoredImagePaths.isEmpty) return old;
      final base = old.split(Platform.pathSeparator).last.split('/').last;
      return restoredImagePaths[base] ?? old;
    }
    for(final j in d['products'] as List) await HiveInit.products.put((j as Map)['id'], Product.fromJson(Map<String,dynamic>.from(j as Map)));
    for(final j in d['customers'] as List) await HiveInit.customers.put((j as Map)['id'], Customer.fromJson(Map<String,dynamic>.from(j as Map)));
    for(final j in d['invoices'] as List) await HiveInit.invoices.put((j as Map)['id'], Invoice.fromJson(Map<String,dynamic>.from(j as Map)));
    for(final j in d['projects'] as List) {
      final proj = Project.fromJson(Map<String,dynamic>.from(j as Map));
      if (restoredImagePaths.isNotEmpty) {
        proj.photoPaths = proj.photoPaths.map(_remapPhoto).toList();
      }
      await HiveInit.projects.put(proj.id, proj);
    }
    for(final j in d['procedures'] as List) await HiveInit.procedures.put((j as Map)['id'], Procedure.fromJson(Map<String,dynamic>.from(j as Map)));
    for(final j in d['transactions'] as List) await HiveInit.transactions.put((j as Map)['id'], TransactionEntry.fromJson(Map<String,dynamic>.from(j as Map)));
    for(final j in (d['personnel'] as List? ?? [])) { final m = Map<String,dynamic>.from(j as Map); await HiveInit.personnel.put(m['id'], PersonnelEntry.fromJson(m)); }
    for(final j in (d['requiredMaterials'] as List? ?? [])) { final m = Map<String,dynamic>.from(j as Map); await HiveInit.requiredMaterials.put(m['id'], RequiredMaterial.fromJson(m)); }
    for(final j in (d['dailyLogs'] as List? ?? [])) { final m = Map<String,dynamic>.from(j as Map); await HiveInit.dailyLogs.put(m['id'], DailyLog.fromJson(m)); }
    for(final j in (d['siteProcedures'] as List? ?? [])) { final m = Map<String,dynamic>.from(j as Map); await HiveInit.siteProcedures.put(m['id'], SiteProcedure.fromJson(m)); }
    for(final j in (d['stockLogs'] as List? ?? [])) { final m = Map<String,dynamic>.from(j as Map); await HiveInit.stockLogs.put(m['id'], StockLog.fromJson(m)); }
    for(final j in (d['priceTiers'] as List? ?? [])) { final m = Map<String,dynamic>.from(j as Map); await HiveInit.priceTiers.put(m['id'], ProductPriceTier.fromJson(m)); }
  }
  static Map<String,dynamic> get jsonSchema=> {"\$schema":"factory_backup v6.0","metadata":{"version":"string","createdAt":"ISO8601"},"products":[{"id":"uuid FK"}],"customers":[{"id":"uuid PK"}],"invoices":[{"customerId":"FK -> customers.id","items":[{"productId":"FK","unitPrice":"invoice-scoped custom price"}],"downPayment":"first payment preview","currency":"SYP fixed"}],"projects":[{"clientId":"FK","currency":"SYP fixed"}],"procedures":[{"projectId":"FK -> projects.id"}],"transactions":[{"partyId":"FK","currency":"SYP fixed","dollarRate":"audit","convertedAmount":"audit"}],"personnel":[{"role":"worker|master|supplier|driver","suppliedMaterials":"supplier items text"}],"requiredMaterials":[{"projectId":"FK -> projects.id","supplierId":"FK -> personnel.id","supplierName":"denormalized","supplierPhone":"denormalized","downPayment":"initial supplier payment SYP"}],"dailyLogs":[{"projectId":"FK -> projects.id"}],"siteProcedures":[{"projectId":"FK","dailyLogId":"FK -> dailyLogs.id"}],"stockLogs":[{"productId":"FK -> products.id","quantityAdded":"restock qty","purchaseCost":"batch total cost","downPayment":"initial supplier payment SYP","suppliedMaterials":"supplier catalog text"}],"priceTiers":[{"productId":"FK -> products.id","unitPrice":"catalog price","startedAt":"interval start","endedAt":"interval end or null=active"}]};
}
enum RestoreResult { success, cancelled, failed }
