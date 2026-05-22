import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:ninho/data/repositories/environments_repository.dart';
import 'package:ninho/data/repositories/shop_repository.dart';
import 'package:ninho/ui/core/theme.dart';
import 'package:ninho/ui/features/shop/transfer_history_screen.dart';

class _FakeEnvRepo extends EnvironmentsRepository {
  _FakeEnvRepo({this.envId = 'env-1'});
  final String? envId;

  @override
  Future<String?> fetchCurrentEnvironmentId() async => envId;
}

class _FakeShopRepo extends ShopRepository {
  const _FakeShopRepo({this.entries = const [], this.error});
  final List<TransferHistoryEntry> entries;
  final Object? error;

  @override
  Future<List<TransferHistoryEntry>> fetchTransferHistory({
    required String environmentId,
    int limit = 20,
  }) async {
    if (error != null) throw error!;
    return entries;
  }
}

void _setMobile(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _wrap({
  required EnvironmentsRepository env,
  required ShopRepository shop,
  String? currentUserId = 'me-id',
}) {
  final router = GoRouter(
    initialLocation: '/shop/history',
    routes: [
      GoRoute(
        path: '/shop/history',
        builder: (_, _) => TransferHistoryScreen(
          environmentsRepository: env,
          shopRepository: shop,
          currentUserId: currentUserId,
        ),
      ),
      GoRoute(
        path: '/shop',
        builder: (_, _) => const Scaffold(body: Text('SHOP')),
      ),
    ],
  );
  return MaterialApp.router(theme: NinhoTheme.light(), routerConfig: router);
}

TransferHistoryEntry _entry({
  String id = 'tr-1',
  String from = 'me-id-abc',
  String to = 'other-id-xyz',
  int cost = 30,
  DateTime? when,
}) {
  return TransferHistoryEntry(
    id: id,
    taskId: 'task-$id',
    fromUserId: from,
    toUserId: to,
    costDust: cost,
    createdAt: when ?? DateTime(2026, 5, 22, 14, 30),
  );
}

void main() {
  testWidgets('empty state quando sem transferências', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(_wrap(env: _FakeEnvRepo(), shop: const _FakeShopRepo()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('transfer_history_empty')), findsOneWidget);
    expect(find.text('Nenhuma transferência ainda'), findsOneWidget);
  });

  testWidgets('lista entradas + destaca "Você" quando sou autor', (
    tester,
  ) async {
    _setMobile(tester);
    final entries = [
      _entry(id: 'a', from: 'me-id', to: 'other-id'),
      _entry(id: 'b', from: 'someone', to: 'me-id', cost: 30),
    ];
    await tester.pumpWidget(
      _wrap(env: _FakeEnvRepo(), shop: _FakeShopRepo(entries: entries)),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Você passou pra morador #other'), findsOneWidget);
    expect(find.textContaining('passou pra você'), findsOneWidget);
    expect(find.textContaining('30'), findsAtLeastNWidgets(2));
  });

  testWidgets('erro mostra mensagem + retry', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrap(
        env: _FakeEnvRepo(),
        shop: const _FakeShopRepo(),
      ),
    );
    // Re-render with error case.
    await tester.pumpWidget(
      _wrap(
        env: _FakeEnvRepo(),
        shop: _FakeShopRepo(error: Exception('boom')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('transfer_history_error')), findsOneWidget);
    expect(find.byKey(const Key('transfer_history_retry')), findsOneWidget);
  });

  testWidgets('sem ninho mostra mensagem de StateError', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrap(env: _FakeEnvRepo(envId: null), shop: const _FakeShopRepo()),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('transfer_history_error')), findsOneWidget);
    expect(find.textContaining('cadastrar um ninho'), findsOneWidget);
  });

  testWidgets('back button pop / fallback go /shop', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrap(env: _FakeEnvRepo(), shop: const _FakeShopRepo()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('transfer_history_back')));
    await tester.pumpAndSettle();

    expect(find.text('SHOP'), findsOneWidget);
  });
}
