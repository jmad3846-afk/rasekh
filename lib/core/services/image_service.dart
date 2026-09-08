import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class ImageService {
  static Future<String> savePermanently(String tempPath) async {
    final src = File(tempPath);
    if (!await src.exists()) {
      throw Exception('الملف المؤقت غير موجود: $tempPath');
    }
    final appDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory('${appDir.path}/project_images');
    if (!await imagesDir.exists()) await imagesDir.create(recursive: true);
    String ext = 'jpg';
    final parts = tempPath.split('.');
    if (parts.length > 1) {
      final cand = parts.last.split('?').first.split('/').last.split('\\').last.toLowerCase();
      if (['jpg','jpeg','png','webp','heic','heif','bmp'].contains(cand)) ext = cand;
    }
    final fileName = '${const Uuid().v4()}.$ext';
    final newPath = '${imagesDir.path}/$fileName';
    try {
      final bytes = await src.readAsBytes();
      final newFile = await File(newPath).writeAsBytes(bytes, flush: true);
      return newFile.path;
    } catch (e) {
      try {
        final newFile = await src.copy(newPath);
        return newFile.path;
      } catch (e2) {
        throw Exception('فشل حفظ الصورة: $e / $e2');
      }
    }
  }
  static Future<void> deleteIfAppImage(String path) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      if (path.startsWith(appDir.path) && await File(path).exists()) await File(path).delete();
    } catch (_) {}
  }
  static bool exists(String path) {
    try { return path.isNotEmpty && File(path).existsSync(); } catch (_) { return false; }
  }
}
class SafeImageFile extends StatelessWidget {
  final String path; final double width; final double height; final double borderRadius; final BoxFit fit; final VoidCallback? onTap;
  const SafeImageFile({super.key, required this.path, required this.width, required this.height, this.borderRadius=12, this.fit=BoxFit.cover, this.onTap});
  @override Widget build(BuildContext context) {
    bool exists = false;
    try { exists = path.isNotEmpty && File(path).existsSync(); } catch (_) {}
    Widget child;
    if (!exists) {
      child = _placeholder();
    } else {
      child = ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.file(File(path), width: width, height: height, fit: fit, errorBuilder: (_,__,___) => _placeholder()),
      );
    }
    if (onTap != null) return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(borderRadius), child: child);
    return child;
  }
  Widget _placeholder() => Container(width: width, height: height, decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(borderRadius), border: Border.all(color: const Color(0xFFE2E8F0))), child: const Column(mainAxisAlignment: MainAxisAlignment.center, children:[Icon(Icons.broken_image_outlined, color: Color(0xFF94A3B8), size: 22), SizedBox(height:4), Text('لا توجد صورة', style: TextStyle(fontSize:9, color: Color(0xFF94A3B8))) ]));
}
void showImageViewer(BuildContext context, List<String> paths, int initialIndex) {
  if (paths.isEmpty) return;
  showDialog(context: context, barrierColor: Colors.black87, builder: (_) => Dialog(backgroundColor: Colors.transparent, insetPadding: const EdgeInsets.all(12), child: Stack(children:[ PageView.builder(controller: PageController(initialPage: initialIndex), itemCount: paths.length, itemBuilder: (_, i) { final p = paths[i]; bool ex=false; try{ex=File(p).existsSync();}catch(_){} if(!ex) return const Center(child: Icon(Icons.broken_image, color: Colors.white, size:48)); return InteractiveViewer(child: Center(child: Image.file(File(p), fit: BoxFit.contain, errorBuilder: (_,__,___)=> const Icon(Icons.broken_image, color: Colors.white, size:48)))); }), Positioned(top:8,right:8, child: IconButton(onPressed: ()=> Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.white, size:28))) ])));
}
