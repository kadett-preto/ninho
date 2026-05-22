import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// IDEA.md §8.4: snapshot do prompt sistema da função `suggest-tasks`.
//
// Falha proposital se o SYSTEM_PROMPT do edge function mudar sem que o
// snapshot seja atualizado. Editar o prompt sem revisar invariantes de
// segurança (§7.6) é a forma mais comum de regredir comportamento de IA.
//
// Pra regenerar: copiar o conteúdo entre as crases template literal de
// `SYSTEM_PROMPT` em supabase/functions/suggest-tasks/index.ts para
// test/snapshots/suggest_tasks_system_prompt.txt.
void main() {
  test('SYSTEM_PROMPT do suggest-tasks bate com snapshot', () {
    final tsFile = File('supabase/functions/suggest-tasks/index.ts');
    expect(
      tsFile.existsSync(),
      isTrue,
      reason: 'Arquivo da edge function não encontrado.',
    );

    final source = tsFile.readAsStringSync();
    // Match único do template literal cru entre as crases.
    final match =
        RegExp(r'const SYSTEM_PROMPT = `([\s\S]*?)`;').firstMatch(source);
    expect(match, isNotNull,
        reason: 'Falha extraindo SYSTEM_PROMPT do index.ts');
    final extracted = match!.group(1)!;

    final snapshot =
        File('test/snapshots/suggest_tasks_system_prompt.txt').readAsStringSync();

    if (extracted != snapshot) {
      // Mensagem clara — devs costumam mexer no prompt sem reler invariantes.
      fail(
        'SYSTEM_PROMPT mudou e o snapshot não foi atualizado.\n'
        'Mudanças aqui afetam segurança contra prompt injection (§7.6).\n'
        'Releia as regras antes de aceitar o diff. Para regenerar:\n'
        '  copie o conteúdo entre as crases em\n'
        '  supabase/functions/suggest-tasks/index.ts para\n'
        '  test/snapshots/suggest_tasks_system_prompt.txt',
      );
    }
  });

  test('SYSTEM_PROMPT contém invariantes de segurança críticas (§7.6)', () {
    final source =
        File('supabase/functions/suggest-tasks/index.ts').readAsStringSync();
    final invariants = <String>[
      // Rótulo opaco — base do mitigador de prompt injection
      'rótulo opaco',
      // Bloqueio explícito a tentativas de jailbreak no nome do cômodo
      'tentativa de injeção',
      // Output só pode ser JSON estruturado
      'Toda saída é JSON respeitando o schema',
      // Sem PII de moradores
      'Nunca inclua dados pessoais',
    ];
    for (final s in invariants) {
      expect(
        source.contains(s),
        isTrue,
        reason: 'Invariante de §7.6 sumiu do SYSTEM_PROMPT: "$s"',
      );
    }
  });
}
