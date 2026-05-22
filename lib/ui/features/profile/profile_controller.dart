import 'package:flutter/foundation.dart';

import '../../../data/repositories/environments_repository.dart';
import '../../../data/repositories/shop_repository.dart';
import '../../../data/repositories/streaks_repository.dart';
import '../../../data/repositories/users_repository.dart';

enum ProfileStatus { idle, loading, ready, error, noEnvironment }

// Ninho — Fase 11.1: tela de Perfil.
//
// Agrega: snapshot do user (display_name/email), sumário do ninho (nome,
// papel), streaks (atual + best individual), saldo de poeira.
// RLS no banco isola tudo por ninho + (no users) pelo próprio id.
class ProfileController extends ChangeNotifier {
  ProfileController({
    UsersRepository? usersRepository,
    EnvironmentsRepository? environmentsRepository,
    StreaksRepository? streaksRepository,
    ShopRepository? shopRepository,
  })  : _usersRepo = usersRepository ?? UsersRepository(),
        _envRepo = environmentsRepository ?? EnvironmentsRepository(),
        _streaksRepo = streaksRepository ?? const StreaksRepository(),
        _shopRepo = shopRepository ?? const ShopRepository();

  final UsersRepository _usersRepo;
  final EnvironmentsRepository _envRepo;
  final StreaksRepository _streaksRepo;
  final ShopRepository _shopRepo;

  ProfileStatus _status = ProfileStatus.idle;
  ProfileStatus get status => _status;

  String? _error;
  String? get error => _error;

  UserProfileSnapshot? _user;
  UserProfileSnapshot? get user => _user;

  EnvironmentSummary? _environment;
  EnvironmentSummary? get environment => _environment;

  StreakSummary _streak = const StreakSummary(
    userCount: 0,
    userBest: 0,
    environmentCount: 0,
    environmentBest: 0,
    freezesLeftMonth: 0,
  );
  StreakSummary get streak => _streak;

  int _dustBalance = 0;
  int get dustBalance => _dustBalance;

  String get displayName {
    final raw = _user?.displayName?.trim();
    if (raw != null && raw.isNotEmpty) return raw;
    final email = _user?.email;
    if (email == null || email.isEmpty) return 'Morador';
    final localPart = email.split('@').first.split(RegExp(r'[\s._-]+')).first;
    if (localPart.isEmpty) return 'Morador';
    return localPart.substring(0, 1).toUpperCase() + localPart.substring(1);
  }

  Future<void> load() async {
    _status = ProfileStatus.loading;
    _error = null;
    notifyListeners();
    try {
      final envId = await _envRepo.fetchCurrentEnvironmentId();
      _user = await _usersRepo.fetchSelf();
      if (envId == null) {
        _status = ProfileStatus.noEnvironment;
        notifyListeners();
        return;
      }
      final results = await Future.wait<Object?>([
        _envRepo.fetchEnvironmentSummary(environmentId: envId),
        _streaksRepo.fetchSummary(environmentId: envId),
        _shopRepo.fetchBalance(environmentId: envId),
      ]);
      _environment = results[0] as EnvironmentSummary?;
      _streak = results[1] as StreakSummary;
      _dustBalance = results[2] as int;
      _status = ProfileStatus.ready;
    } catch (e) {
      _status = ProfileStatus.error;
      _error = _humanize(e);
    } finally {
      notifyListeners();
    }
  }

  String _humanize(Object e) {
    if (e is StateError) return e.message;
    final msg = e.toString();
    if (msg.contains('42501')) return 'Sem permissão para ver o perfil.';
    return 'Não conseguimos carregar o perfil agora.';
  }
}
