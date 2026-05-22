// Engine puro de streak — IDEA.md §5.7.
//
// Streak de usuário: contador diário; falhar uma task zera. Cada usuário
// tem 2 freezes/mês que cobrem 1 dia de falha. Freezes não acumulam.
//
// Streak de ninho: contador diário coletivo. Se *qualquer* morador falhar
// no dia (mesmo com freeze pessoal), o streak do ninho zera. Freezes
// individuais NÃO cobrem o streak do ninho.
//
// Modo viagem (vacation): owner pausa o ninho até 14d/ano. Dias dentro do
// intervalo de viagem ignoram avaliação — streaks ficam intactos.
//
// Esta engine é pura: aceita dependências como parâmetros (clock injetável,
// estado prévio do streak) e devolve novo estado. Não toca em I/O. Use
// para preview no cliente e para implementação canônica no servidor.

class StreakInput {
  const StreakInput({
    required this.evaluationDate,
    required this.userIds,
    required this.tasks,
    required this.completions,
    required this.priorUserStreaks,
    required this.priorEnvironmentStreak,
    this.vacationDays = const [],
  });

  // Dia (local do fuso do ninho) a ser avaliado — meia-noite.
  // A engine avalia o dia que ACABOU de terminar. Para avaliar hoje,
  // chame depois da virada de dia (00:00:01) com o dia que terminou.
  final DateTime evaluationDate;

  // Moradores ativos do ninho neste dia.
  final List<String> userIds;

  // Tasks ativas no ninho neste dia.
  final List<StreakTask> tasks;

  // Completions registradas no dia avaliado (qualquer task / qualquer user).
  final List<StreakCompletion> completions;

  // Estado prévio por usuário. Map<userId, StreakState>.
  final Map<String, StreakState> priorUserStreaks;

  final StreakState priorEnvironmentStreak;

  // Datas (UTC ou local truncado em meia-noite) marcadas como modo
  // viagem do ninho. Dias presentes aqui ignoram avaliação.
  final List<DateTime> vacationDays;
}

class StreakTask {
  const StreakTask({
    required this.id,
    required this.assigneeId,
    required this.startDate,
    this.intervalDays = 1,
  });

  final String id;
  // Morador responsável. Se null, a task não conta para o streak de
  // ninguém (decisão MVP — IDEA.md §5.7 não pinou unowned tasks).
  final String? assigneeId;

  // start_date da task (DateTime sem hora — assumimos meia-noite local
  // do fuso do ninho).
  final DateTime startDate;

  // Intervalo em dias da RRULE FREQ=DAILY;INTERVAL=N. 1 = diária.
  final int intervalDays;

  // Task ativa em [date] se: date >= startDate e (date - startDate).days
  // é múltiplo de intervalDays.
  bool isExpectedOn(DateTime date) {
    if (date.isBefore(startDate)) return false;
    final delta = date.difference(startDate).inDays;
    if (delta < 0) return false;
    if (intervalDays <= 1) return true;
    return delta % intervalDays == 0;
  }
}

class StreakCompletion {
  const StreakCompletion({
    required this.taskId,
    required this.completedBy,
    required this.completedAt,
  });

  final String taskId;
  final String completedBy;
  final DateTime completedAt;
}

class StreakState {
  const StreakState({
    required this.current,
    required this.best,
    required this.freezesLeftMonth,
    required this.monthKey,
  });

  factory StreakState.initial(DateTime now) {
    return StreakState(
      current: 0,
      best: 0,
      freezesLeftMonth: 2,
      monthKey: _monthKey(now),
    );
  }

  final int current;
  final int best;
  // Freezes restantes no mês corrente. Tasks de ninho NÃO consomem.
  final int freezesLeftMonth;
  // YYYY-MM do mês a que `freezesLeftMonth` se refere — usado pelo
  // engine para resetar a cota na virada de mês.
  final String monthKey;

  StreakState copyWith({
    int? current,
    int? best,
    int? freezesLeftMonth,
    String? monthKey,
  }) {
    return StreakState(
      current: current ?? this.current,
      best: best ?? this.best,
      freezesLeftMonth: freezesLeftMonth ?? this.freezesLeftMonth,
      monthKey: monthKey ?? this.monthKey,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StreakState &&
          current == other.current &&
          best == other.best &&
          freezesLeftMonth == other.freezesLeftMonth &&
          monthKey == other.monthKey;

  @override
  int get hashCode => Object.hash(current, best, freezesLeftMonth, monthKey);

  @override
  String toString() =>
      'StreakState(current: $current, best: $best, freezes: $freezesLeftMonth, month: $monthKey)';
}

class StreakOutcome {
  const StreakOutcome({
    required this.userStreaks,
    required this.environmentStreak,
    required this.userOutcomes,
    required this.environmentOutcome,
  });

  final Map<String, StreakState> userStreaks;
  final StreakState environmentStreak;
  // Por usuário: 'kept' (sem falha) / 'frozen' (falhou mas usou freeze) /
  // 'broken' (falhou e não tinha freeze).
  final Map<String, StreakDayOutcome> userOutcomes;
  // Para o ninho: 'kept' / 'broken' / 'paused' (vacation).
  final StreakDayOutcome environmentOutcome;
}

enum StreakDayOutcome { kept, frozen, broken, paused }

class StreakEngine {
  const StreakEngine();

  StreakOutcome evaluate(StreakInput input) {
    final day = _truncate(input.evaluationDate);
    final monthKey = _monthKey(day);

    // Modo viagem: dia em vacationDays → tudo pausado. Streaks intactos,
    // freezes preservados.
    final isVacation = input.vacationDays.any(
      (d) => _truncate(d) == day,
    );
    if (isVacation) {
      final users = <String, StreakState>{};
      for (final uid in input.userIds) {
        final prior = input.priorUserStreaks[uid] ??
            StreakState.initial(day);
        users[uid] = _rollMonth(prior, monthKey);
      }
      return StreakOutcome(
        userStreaks: users,
        environmentStreak: _rollMonth(input.priorEnvironmentStreak, monthKey),
        userOutcomes: {
          for (final uid in input.userIds) uid: StreakDayOutcome.paused,
        },
        environmentOutcome: StreakDayOutcome.paused,
      );
    }

    // Tasks esperadas no dia por usuário.
    final expectedPerUser = <String, Set<String>>{};
    for (final uid in input.userIds) {
      expectedPerUser[uid] = {};
    }
    for (final task in input.tasks) {
      if (task.assigneeId == null) continue;
      if (!task.isExpectedOn(day)) continue;
      final bucket = expectedPerUser[task.assigneeId];
      if (bucket != null) bucket.add(task.id);
    }

    // Completions agrupadas por (user, task) no dia.
    final completedPerUser = <String, Set<String>>{};
    for (final uid in input.userIds) {
      completedPerUser[uid] = {};
    }
    for (final c in input.completions) {
      if (_truncate(c.completedAt) != day) continue;
      final bucket = completedPerUser[c.completedBy];
      if (bucket != null) bucket.add(c.taskId);
    }

    final userStreaks = <String, StreakState>{};
    final userOutcomes = <String, StreakDayOutcome>{};
    var anyUserMissed = false;

    for (final uid in input.userIds) {
      final prior = input.priorUserStreaks[uid] ?? StreakState.initial(day);
      final state = _rollMonth(prior, monthKey);
      final expected = expectedPerUser[uid] ?? const <String>{};
      final completed = completedPerUser[uid] ?? const <String>{};
      final missed = expected.difference(completed);

      if (missed.isEmpty) {
        // Sem tasks ou todas concluídas — streak avança. Sem tasks
        // esperadas conta como "dia limpo" (não quebra).
        final next = state.current + 1;
        userStreaks[uid] = state.copyWith(
          current: next,
          best: next > state.best ? next : state.best,
        );
        userOutcomes[uid] = StreakDayOutcome.kept;
        continue;
      }

      anyUserMissed = true;
      if (state.freezesLeftMonth > 0) {
        // Freeze consumido — streak mantém valor (não avança nem
        // zera). IDEA.md §5.7: freeze "cobre 1 dia de falha sem zerar".
        userStreaks[uid] = state.copyWith(
          freezesLeftMonth: state.freezesLeftMonth - 1,
        );
        userOutcomes[uid] = StreakDayOutcome.frozen;
      } else {
        userStreaks[uid] = state.copyWith(current: 0);
        userOutcomes[uid] = StreakDayOutcome.broken;
      }
    }

    // Streak de ninho: qualquer falha (mesmo coberta por freeze
    // individual) zera. Avança só se ninguém perdeu nenhuma task.
    final envPrior = _rollMonth(input.priorEnvironmentStreak, monthKey);
    StreakState envNext;
    StreakDayOutcome envOutcome;
    if (anyUserMissed) {
      envNext = envPrior.copyWith(current: 0);
      envOutcome = StreakDayOutcome.broken;
    } else {
      final c = envPrior.current + 1;
      envNext = envPrior.copyWith(
        current: c,
        best: c > envPrior.best ? c : envPrior.best,
      );
      envOutcome = StreakDayOutcome.kept;
    }

    return StreakOutcome(
      userStreaks: userStreaks,
      environmentStreak: envNext,
      userOutcomes: userOutcomes,
      environmentOutcome: envOutcome,
    );
  }

  // Vira o mês: se o monthKey atual difere do estado anterior, reseta
  // freezesLeftMonth para 2 (IDEA.md §5.7: não acumuláveis).
  StreakState _rollMonth(StreakState state, String monthKey) {
    if (state.monthKey == monthKey) return state;
    return state.copyWith(
      freezesLeftMonth: 2,
      monthKey: monthKey,
    );
  }
}

DateTime _truncate(DateTime d) => DateTime(d.year, d.month, d.day);

String _monthKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';
