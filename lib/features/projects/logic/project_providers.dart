import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/hive_init.dart';
import '../data/models/project.dart';
import '../data/models/procedure.dart';
import '../../finance/logic/finance_engine.dart';

final projectsProvider = StreamProvider<List<Project>>((ref) async* { final box=HiveInit.projects; yield box.values.toList()..sort((a,b)=> b.createdAt.compareTo(a.createdAt)); yield* box.watch().map((_)=> box.values.toList()..sort((a,b)=> b.createdAt.compareTo(a.createdAt))); });
final proceduresProvider = StreamProvider.family<List<Procedure>,String>((ref,projectId) async* { final box=HiveInit.procedures; List<Procedure> getList()=> box.values.where((p)=> p.projectId==projectId).toList()..sort((a,b)=> b.date.compareTo(a.date)); yield getList(); yield* box.watch().map((_)=> getList()); });
class ProjectService {
  Future<void> add(Project p) async => await HiveInit.projects.put(p.id,p);
  Future<void> update(Project p) async => await p.save();
  Future<void> delete(Project p) async { final procs=HiveInit.procedures.values.where((e)=> e.projectId==p.id).toList(); for(final pr in procs) await pr.delete(); await p.delete(); }
  Future<void> addProcedure(Procedure proc) async { proc.recalc(); final project=HiveInit.projects.get(proc.projectId); if(project==null) throw Exception('Project not found'); await HiveInit.procedures.put(proc.id,proc); await FinanceEngine.onProcedureAdded(proc, project); }
  Future<void> updateProcedureStatus(Procedure proc, ProcedureStatus newStatus) async { final old=proc.status; if(old==newStatus) return; final project=HiveInit.projects.get(proc.projectId); if(project==null) throw Exception('Project not found'); proc.status=newStatus; await proc.save(); await FinanceEngine.onProcedureStatusChanged(proc, project, old); }
  Future<void> deleteProcedure(Procedure proc) async { final project=HiveInit.projects.get(proc.projectId); if(project!=null) await FinanceEngine.onProcedureDeleted(proc, project); await proc.delete(); }
}
final projectServiceProvider = Provider((ref)=> ProjectService());
