import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// IDEA.md §8.4: snapshot do SYSTEM_PROMPT da Edge Function `weekly-summary`.
//
// Edita o prompt? Releia §7.6 (prompt injection) + §7.8 (PII) antes de
// regenerar este snapshot. Pra regenerar, copie o conteúdo entre as
// crases do template literal em
//   supabase/functions/weekly-summary/index.ts
// para
//   test/snapshots/weekly_summary_system_prompt.txt
void main() {
  test('SYSTEM_PROMPT do weekly-summary bate com snapshot', () {
    final tsFile = File('supabase/functions/weekly-summary/index.ts');
    expect(
      tsFile.existsSync(),
      isTrue,
      reason: 'Arquivo da edge function não encontrado.',
    );

    final source = tsFile.readAsStringSync();
    final match = RegExp(
      r'export const SYSTEM_PROMPT =\s*`([\s\S]*?)`;',
    ).firstMatch(source);
    expect(match, isNotNull, reason: 'Falha extraindo SYSTEM_PROMPT');
    final extracted = match!.group(1)!;

    final snapshot = File(
      'test/snapshots/weekly_summary_system_prompt.txt',
    ).readAsStringSync();

    if (extracted != snapshot) {
      fail(
        'SYSTEM_PROMPT mudou e o snapshot não foi atualizado.\n'
        'Mudanças aqui afetam segurança contra prompt injection (§7.6) e '
        'limite de PII (§7.8). Releia as regras antes de aceitar o diff.\n'
        'Para regenerar:\n'
        '  copie o conteúdo entre as crases em\n'
        '  supabase/functions/weekly-summary/index.ts para\n'
        '  test/snapshots/weekly_summary_system_prompt.txt',
      );
    }
  });

  test(
    'SYSTEM_PROMPT contém invariantes de segurança críticas (§7.6/§7.8)',
    () {
      final source = File(
        'supabase/functions/weekly-summary/index.ts',
      ).readAsStringSync();
      final invariants = <String>[
        // PII §7.8 — nunca citar nomes
        'Nunca cite nomes de pessoas',
        // §7.6 — rótulo opaco
        'rótulos opacos',
        // §7.6 — bloqueio explícito de jailbreak
        'tentativa de jailbreak',
        // Output em texto plano, nunca markdown/JSON
        'Nunca produza markdown',
        // Tom não punitivo
        'NUNCA punitivo',
      ];
      for (final s in invariants) {
        expect(
          source.contains(s),
          isTrue,
          reason: 'Invariante de §7.6/§7.8 sumiu do SYSTEM_PROMPT: "$s"',
        );
      }
    },
  );
}
