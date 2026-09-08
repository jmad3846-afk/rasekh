import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/image_service.dart';
import '../../data/models/project.dart';
import '../../logic/project_providers.dart';

class ProjectFormScreen extends ConsumerStatefulWidget {
  final Project? project;
  const ProjectFormScreen({super.key, this.project});
  @override ConsumerState<ProjectFormScreen> createState()=> _S();
}
class _S extends ConsumerState<ProjectFormScreen> {
  final _form=GlobalKey<FormState>();
  late TextEditingController name, phone, location, totalArea, buildingArea, rooms, desc;
  List<String> photos=[];
  bool _picking=false;

  @override void initState(){
    super.initState();
    name=TextEditingController(text: widget.project?.clientName??'');
    phone=TextEditingController(text: widget.project?.clientPhone??'');
    location=TextEditingController(text: widget.project?.location??'');
    totalArea=TextEditingController(text: widget.project?.totalArea.toString()??'');
    buildingArea=TextEditingController(text: widget.project?.buildingArea.toString()??'');
    rooms=TextEditingController(text: widget.project?.roomCount.toString()??'');
    desc=TextEditingController(text: widget.project?.description??'');
    photos=List.from(widget.project?.photoPaths??[]);
  }

  Future<void> pickImage() async {
    if(_picking) return;
    setState(()=> _picking=true);
    try{
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        builder: (_)=> SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children:[
          ListTile(leading: const Icon(Icons.photo_library_outlined), title: Text('المعرض', style: GoogleFonts.cairo()), subtitle: Text('اختيار صورة من الجهاز', style: GoogleFonts.cairo(fontSize:11, color: AppColors.textSecondary)), onTap: ()=> Navigator.pop(context, ImageSource.gallery)),
          ListTile(leading: const Icon(Icons.photo_camera_outlined), title: Text('الكاميرا', style: GoogleFonts.cairo()), onTap: ()=> Navigator.pop(context, ImageSource.camera)),
        ])),
      );
      if(source==null) return;

      String? tempPath;
      String? debugInfo;

      if (source == ImageSource.gallery) {
        // GALLERY: Try file_picker first (works on Windows + Android SAF without permission)
        // Do NOT request permission for gallery - system picker handles it and request may cause failure on Windows
        try {
          final res = await FilePicker.platform.pickFiles(
            type: FileType.image,
            allowMultiple: false,
            withData: false,
            // on Android, allow compression? file_picker doesn't compress, we handle later
          );
          if (res != null && res.files.isNotEmpty) {
            final f = res.files.single;
            tempPath = f.path;
            debugInfo = 'file_picker: name=${f.name} path=$tempPath bytes=${f.bytes?.length} size=${f.size} ext=${f.extension}';
            if (tempPath == null && f.bytes != null) {
              // SAF returned bytes only (Android scoped storage) - write to temp file
              final tmpDir = await Directory.systemTemp.createTemp('pick_');
              final tmpFile = File('${tmpDir.path}/${f.name}');
              await tmpFile.writeAsBytes(f.bytes!);
              tempPath = tmpFile.path;
              debugInfo += ' -> wrote temp $tempPath';
            }
            if (tempPath == null || tempPath.isEmpty) {
              // No path and no bytes - this is the failure case user sees
              debugInfo += ' -> PATH NULL, will fallback to image_picker';
            }
          } else {
            // User cancelled - not an error
            return;
          }
        } catch (e, st) {
          debugPrint('file_picker gallery failed: $e\n$st');
          debugInfo = 'file_picker error: $e';
          // Fall through to fallback
          tempPath = null;
        }

        // FALLBACK to image_picker gallery if file_picker gave no path
        if (tempPath == null || tempPath.isEmpty) {
          try {
            debugPrint('Trying image_picker gallery fallback...');
            final picker = ImagePicker();
            final x = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70, maxWidth: 1600);
            if (x != null) {
              tempPath = x.path;
              debugInfo = (debugInfo ?? '') + ' | image_picker fallback: $tempPath';
            } else {
              // User cancelled fallback
              if (debugInfo != null) debugPrint(debugInfo);
              return;
            }
          } catch (e, st) {
            debugPrint('image_picker gallery fallback failed: $e\n$st');
            throw Exception('فشل المعرض (file_picker + image_picker): $debugInfo | fallback error: $e');
          }
        }
      } else {
        // CAMERA: must use image_picker, request camera permission only on Android/iOS
        if (!kIsWeb && Platform.isAndroid || Platform.isIOS) {
          try {
            final s = await Permission.camera.request();
            if (s.isDenied || s.isPermanentlyDenied) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('إذن الكاميرا مرفوض - فعّله من الإعدادات > التطبيق > الأذونات', style: GoogleFonts.cairo()), backgroundColor: AppColors.error, action: SnackBarAction(label: 'الإعدادات', textColor: Colors.white, onPressed: ()=> openAppSettings())));
              return;
            }
          } catch (_) {}
        }
        final picker = ImagePicker();
        final x = await picker.pickImage(source: ImageSource.camera, imageQuality: 70, maxWidth: 1600);
        if (x == null) return;
        tempPath = x.path;
      }

      if(tempPath == null || tempPath.isEmpty) {
        throw Exception('لم يتم الحصول على مسار الملف. تفاصيل: $debugInfo');
      }

      // Validate existence async (don't use sync which may throw on content://)
      final exists = await File(tempPath).exists();
      if(!exists) {
        // Try to give helpful message
        throw Exception('الملف غير موجود بعد الاختيار: $tempPath | $debugInfo');
      }

      // Try to persist, but if it fails, use original path as fallback so user still sees image
      String finalPath = tempPath;
      try {
        finalPath = await ImageService.savePermanently(tempPath);
      } catch (e) {
        debugPrint('savePermanently failed, using original path: $e');
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تحذير: سيتم استخدام المسار الأصلي (قد يُفقد بعد إعادة التشغيل): $e', style: GoogleFonts.cairo(fontSize:12)), backgroundColor: AppColors.warning, duration: const Duration(seconds:2)));
        finalPath = tempPath;
      }

      if(mounted) setState(()=> photos.add(finalPath));
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تمت إضافة الصورة ✓', style: GoogleFonts.cairo()), backgroundColor: AppColors.success, duration: const Duration(seconds:1)));
    } catch(e, st){
      debugPrint('pickImage FINAL error: $e\n$st');
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل اختيار الصورة: $e', style: GoogleFonts.cairo(fontSize:13)), backgroundColor: AppColors.error, duration: const Duration(seconds:4)));
    } finally {
      if(mounted) setState(()=> _picking=false);
    }
  }

  Future<void> _removeAt(int i) async {
    final path = photos[i];
    setState(()=> photos.removeAt(i));
    await ImageService.deleteIfAppImage(path);
  }

  @override Widget build(BuildContext context){
    final isEdit=widget.project!=null;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit?'تعديل التعهد':'تعهد جديد', style: GoogleFonts.cairo(fontWeight: FontWeight.w800))),
      body: Form(key:_form, child: ListView(padding: const EdgeInsets.all(16), children:[
        Text('بيانات العميل والموقع *', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
        const SizedBox(height:8),
        TextFormField(controller:name, decoration: const InputDecoration(labelText:'اسم العميل *', prefixIcon: Icon(Icons.person)), validator:(v)=> v!.isEmpty?'مطلوب':null),
        const SizedBox(height:12),
        TextFormField(controller:phone, decoration: const InputDecoration(labelText:'رقم الهاتف *', prefixIcon: Icon(Icons.phone)), keyboardType: TextInputType.phone, validator:(v)=> v!.isEmpty?'مطلوب':null),
        const SizedBox(height:12),
        TextFormField(controller:location, decoration: const InputDecoration(labelText:'موقع الشقة / المشروع *', prefixIcon: Icon(Icons.location_on)), validator:(v)=> v!.isEmpty?'مطلوب':null),
        const SizedBox(height:12),
        Row(children:[
          Expanded(child: TextFormField(controller:totalArea, decoration: const InputDecoration(labelText:'المساحة الكلية م² *'), keyboardType: TextInputType.number, validator:(v)=> v!.isEmpty?'مطلوب':null)),
          const SizedBox(width:12),
          Expanded(child: TextFormField(controller:buildingArea, decoration: const InputDecoration(labelText:'مساحة البناء م² *'), keyboardType: TextInputType.number, validator:(v)=> v!.isEmpty?'مطلوب':null)),
        ]),
        const SizedBox(height:12),
        TextFormField(controller:rooms, decoration: const InputDecoration(labelText:'عدد الغرف *', prefixIcon: Icon(Icons.meeting_room_outlined)), keyboardType: TextInputType.number, validator:(v)=> v!.isEmpty?'مطلوب':null),
        const SizedBox(height:12),
        TextFormField(controller:desc, decoration: const InputDecoration(labelText:'وصف مختصر *', hintText:'نوع التشطيب، طوابق...'), maxLines:3, validator:(v)=> v!.isEmpty?'مطلوب':null),
        const SizedBox(height:16),
        Row(children:[Text('صور العقد', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)), const Spacer(), OutlinedButton.icon(onPressed: _picking?null:pickImage, icon: _picking? const SizedBox(width:14,height:14, child: CircularProgressIndicator(strokeWidth:2)): const Icon(Icons.add_a_photo), label: Text(_picking?'جاري...':'إضافة صورة', style: GoogleFonts.cairo()))]),
        const SizedBox(height:8),
        if(photos.isEmpty) Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(12)), child: Center(child: Text('لم يتم اختيار صور - اضغط "إضافة صورة"', style: GoogleFonts.cairo(color: AppColors.textSecondary)))),
        if(photos.isNotEmpty) SizedBox(height:110, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: photos.length, separatorBuilder: (_,__)=> const SizedBox(width:8), itemBuilder: (_,i){
          final p = photos[i];
          return Stack(children:[
            SafeImageFile(
              path: p, width: 110, height: 110, borderRadius: 12,
              onTap: ()=> showImageViewer(context, photos, i),
            ),
            Positioned(top:4,right:4, child: InkWell(onTap: ()=> _removeAt(i), child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.close, color: Colors.white, size:14)))),
          ]);
        })),
        if(photos.isNotEmpty) Padding(padding: const EdgeInsets.only(top:6), child: Text('اضغط على الصورة لعرضها بحجم كامل • ${photos.length} صورة', style: GoogleFonts.cairo(fontSize:11, color: AppColors.textSecondary))),
        const SizedBox(height:24),
        SizedBox(width:double.infinity, child: ElevatedButton(onPressed: () async {
          if(!_form.currentState!.validate()) return;
          if(isEdit){
            final p=widget.project!;
            p.clientName=name.text; p.clientPhone=phone.text; p.location=location.text;
            p.totalArea=double.parse(totalArea.text); p.buildingArea=double.parse(buildingArea.text);
            p.roomCount=int.parse(rooms.text); p.description=desc.text; p.photoPaths=photos;
            await ref.read(projectServiceProvider).update(p);
          } else {
            final p=Project(clientName:name.text, clientPhone:phone.text, location:location.text, totalArea: double.parse(totalArea.text), buildingArea: double.parse(buildingArea.text), roomCount: int.parse(rooms.text), description: desc.text, photoPaths: photos);
            await ref.read(projectServiceProvider).add(p);
          }
          if(mounted) Navigator.pop(context);
        }, child: Text(isEdit?'حفظ التعديل':'إنشاء المشروع'))),
      ])),
    );
  }
}
