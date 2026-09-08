import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/database/hive_init.dart';
import '../../factory/data/models/product.dart';
import '../../factory/data/models/customer.dart';
import '../../factory/data/models/invoice.dart';
import '../../projects/data/models/project.dart';
import '../../projects/data/models/procedure.dart';
import '../../finance/data/models/transaction.dart';

class BackupService {
  static const String backupVersion = '1.0';
  static Map<String,dynamic> _buildJson() {
    final now = DateTime.now();
    return {
      'metadata': {'version': backupVersion,'createdAt': now.toIso8601String(),'app': 'Factory_Managment','counts': {'products': HiveInit.products.length,'customers': HiveInit.customers.length,'invoices': HiveInit.invoices.length,'projects': HiveInit.projects.length,'procedures': HiveInit.procedures.length,'transactions': HiveInit.transactions.length}},
      'products': HiveInit.products.values.map((e)=> e.toJson()).toList(),
      'customers': HiveInit.customers.values.map((e)=> e.toJson()).toList(),
      'invoices': HiveInit.invoices.values.map((e)=> e.toJson()).toList(),
      'projects': HiveInit.projects.values.map((e)=> e.toJson()).toList(),
      'procedures': HiveInit.procedures.values.map((e)=> e.toJson()).toList(),
      'transactions': HiveInit.transactions.values.map((e)=> e.toJson()).toList(),
    };
  }
  static String _timestamp() { final n=DateTime.now(); String two(int v)=> v.toString().padLeft(2,'0'); return '${n.year}-${two(n.month)}-${two(n.day)}_${two(n.hour)}${two(n.minute)}';}
  static String _checksum(String s)=> sha256.convert(utf8.encode(s)).toString();
  static Future<String?> exportBackup({bool asZip=true}) async {
    final data=_buildJson(); final jsonStr=const JsonEncoder.withIndent('  ').convert(data); final checksum=_checksum(jsonStr); final fileName='Factory_Backup_${_timestamp()}';
    String? dir=await FilePicker.platform.getDirectoryPath(dialogTitle:'اختر مكان حفظ النسخة (SD/USB)');
    if(dir==null) return null;
    if(asZip){
      final archive=Archive();
      archive.addFile(ArchiveFile('data.json', jsonStr.length, utf8.encode(jsonStr)));
      archive.addFile(ArchiveFile('checksum.txt', checksum.length, utf8.encode(checksum)));
      archive.addFile(ArchiveFile('metadata.txt', 200, utf8.encode('Version:$backupVersion\nCreated:${DateTime.now().toIso8601String()}\nChecksum:$checksum')));
      final allPaths=<String>{...HiveInit.projects.values.expand((p)=> p.photoPaths)};
      for(final path in allPaths){ try{ final f=File(path); if(await f.exists()){ final bytes=await f.readAsBytes(); final name=path.split(Platform.pathSeparator).last; archive.addFile(ArchiveFile('images/$name', bytes.length, bytes));}}catch(_){}
      }
      final zipBytes=ZipEncoder().encode(archive); final out=File('$dir/$fileName.zip'); await out.writeAsBytes(zipBytes!); return out.path;
    } else { final out=File('$dir/$fileName.json'); await out.writeAsString(jsonStr); await File('$dir/$fileName.checksum.txt').writeAsString(checksum); return out.path; }
  }
  static Future<RestoreResult> restoreBackup() async {
    final res=await FilePicker.platform.pickFiles(type:FileType.any, allowMultiple:false);
    if(res==null||res.files.isEmpty) return RestoreResult.cancelled;
    final file=File(res.files.single.path!); Map<String,dynamic> data;
    if(file.path.endsWith('.zip')){
      final bytes=await file.readAsBytes(); final archive=ZipDecoder().decodeBytes(bytes);
      final dataFile=archive.files.firstWhere((f)=> f.name=='data.json', orElse:()=> throw Exception('Invalid backup: data.json missing'));
      final jsonStr=utf8.decode(dataFile.content as List<int>);
      final checksumFile=archive.files.where((f)=> f.name=='checksum.txt').firstOrNull;
      if(checksumFile!=null){ final expected=utf8.decode(checksumFile.content as List<int>).trim(); final actual=_checksum(jsonStr); if(expected!=actual) throw Exception('فشل التحقق: checksum غير متطابق - الملف تالف');}
      data=jsonDecode(jsonStr);
      final appDir=await getApplicationDocumentsDirectory(); final imgDir=Directory('${appDir.path}/restored_images'); if(!await imgDir.exists()) await imgDir.create(recursive:true);
      for(final f in archive.files.where((e)=> e.name.startsWith('images/'))){ final out=File('${imgDir.path}/${f.name.split('/').last}'); await out.writeAsBytes(f.content as List<int>); }
    } else { final jsonStr=await file.readAsString(); data=jsonDecode(jsonStr); }
    _validate(data); await _clearAll(); await _restore(data); return RestoreResult.success;
  }
  static void _validate(Map<String,dynamic> d){ const req=['products','customers','invoices','projects','procedures','transactions','metadata']; for(final k in req) if(!d.containsKey(k)) throw Exception('Invalid backup: missing $k'); final cIds=(d['customers'] as List).map((e)=> e['id']).toSet(); for(final inv in d['invoices'] as List) if(!cIds.contains(inv['customerId'])) throw Exception('FK violation: invoice ${inv['id']}'); final pIds=(d['projects'] as List).map((e)=> e['id']).toSet(); for(final pr in d['procedures'] as List) if(!pIds.contains(pr['projectId'])) throw Exception('FK violation: procedure ${pr['id']}');}
  static Future<void> _clearAll() async { await HiveInit.products.clear(); await HiveInit.customers.clear(); await HiveInit.invoices.clear(); await HiveInit.projects.clear(); await HiveInit.procedures.clear(); await HiveInit.transactions.clear();}
  static Future<void> _restore(Map<String,dynamic> d) async { for(final j in d['products'] as List) await HiveInit.products.put(j['id'], Product.fromJson(Map<String,dynamic>.from(j))); for(final j in d['customers'] as List) await HiveInit.customers.put(j['id'], Customer.fromJson(Map<String,dynamic>.from(j))); for(final j in d['invoices'] as List) await HiveInit.invoices.put(j['id'], Invoice.fromJson(Map<String,dynamic>.from(j))); for(final j in d['projects'] as List) await HiveInit.projects.put(j['id'], Project.fromJson(Map<String,dynamic>.from(j))); for(final j in d['procedures'] as List) await HiveInit.procedures.put(j['id'], Procedure.fromJson(Map<String,dynamic>.from(j))); for(final j in d['transactions'] as List) await HiveInit.transactions.put(j['id'], TransactionEntry.fromJson(Map<String,dynamic>.from(j))); }
  static Map<String,dynamic> get jsonSchema=> {"\$schema":"factory_backup v1.0","metadata":{"version":"string","createdAt":"ISO8601"},"products":[{"id":"uuid FK"}],"customers":[{"id":"uuid PK"}],"invoices":[{"customerId":"FK -> customers.id"}],"projects":[{"clientId":"FK"}],"procedures":[{"projectId":"FK -> projects.id"}],"transactions":[{"partyId":"FK"}]};
}
enum RestoreResult { success, cancelled, failed }
