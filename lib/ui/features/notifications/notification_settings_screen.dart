import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/notifications_repository.dart';
import '../../core/colors.dart';
import '../../core/spacing.dart';
import 'notification_settings_controller.dart';

// Stitch — "Configurar Horários de Notificação" (dde54107f2b54a4abe97fc3de2349c90).
class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key, this.repository});

  final NotificationsRepository? repository;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<NotificationSettingsController>(
      create: (_) => NotificationSettingsController(repository: repository)
        ..load(),
      child: const _View(),
    );
  }
}

class _View extends StatelessWidget {
  const _View();

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<NotificationSettingsController>();
    return Scaffold(
      backgroundColor: NinhoColors.background,
      appBar: AppBar(
        backgroundColor: NinhoColors.background,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          key: const Key('notif_settings_back'),
          icon: const Icon(Icons.arrow_back, color: NinhoColors.primary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Notificações',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: NinhoColors.primary,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
      body: _Body(controller: ctrl),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.controller});
  final NotificationSettingsController controller;

  @override
  Widget build(BuildContext context) {
    switch (controller.status) {
      case NotifSettingsStatus.idle:
      case NotifSettingsStatus.loading:
        return const Center(
          child: CircularProgressIndicator(color: NinhoColors.primary),
        );
      case NotifSettingsStatus.error:
        if (controller.prefs == null) {
          return _ErrorView(message: controller.error ?? 'Erro desconhecido');
        }
        return _Form(controller: controller);
      case NotifSettingsStatus.ready:
      case NotifSettingsStatus.saving:
        return _Form(controller: controller);
    }
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(NinhoSpacing.marginMobile),
      child: Center(
        child: Text(
          message,
          key: const Key('notif_settings_error'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: NinhoColors.error,
              ),
        ),
      ),
    );
  }
}

class _Form extends StatelessWidget {
  const _Form({required this.controller});
  final NotificationSettingsController controller;

  @override
  Widget build(BuildContext context) {
    final p = controller.prefs!;
    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              NinhoSpacing.marginMobile,
              NinhoSpacing.stackMd,
              NinhoSpacing.marginMobile,
              120,
            ),
            children: [
              _Section(
                title: 'Receber lembretes',
                children: [
                  _SwitchTile(
                    key: const Key('notif_toggle_master'),
                    title: 'Ativar todas as notificações',
                    subtitle: p.pushEnabled
                        ? 'Você recebe lembretes e eventos do ninho.'
                        : 'Tudo silenciado.',
                    value: p.pushEnabled,
                    onChanged: controller.togglePushEnabled,
                  ),
                ],
              ),
              const SizedBox(height: NinhoSpacing.stackLg),
              _Section(
                title: 'Horários',
                children: [
                  _TimeTile(
                    keyValue: 'notif_time_morning',
                    label: 'Manhã',
                    minutes: p.morningTime,
                    enabled: p.pushEnabled,
                    onPick: controller.setMorning,
                  ),
                  _TimeTile(
                    keyValue: 'notif_time_afternoon',
                    label: 'Tarde',
                    minutes: p.afternoonTime,
                    enabled: p.pushEnabled,
                    onPick: controller.setAfternoon,
                  ),
                  _TimeTile(
                    keyValue: 'notif_time_evening',
                    label: 'Noite',
                    minutes: p.eveningTime,
                    enabled: p.pushEnabled,
                    onPick: controller.setEvening,
                  ),
                ],
              ),
              const SizedBox(height: NinhoSpacing.stackLg),
              _Section(
                title: 'Outras notificações',
                children: [
                  _SwitchTile(
                    key: const Key('notif_event_task_transferred'),
                    title: 'Tarefa transferida pra você',
                    value: p.eventTaskTransferred,
                    onChanged: p.pushEnabled
                        ? (v) =>
                            controller.toggleEvent(taskTransferred: v)
                        : null,
                  ),
                  _SwitchTile(
                    key: const Key('notif_event_new_member'),
                    title: 'Novo membro',
                    value: p.eventNewMember,
                    onChanged: p.pushEnabled
                        ? (v) => controller.toggleEvent(newMember: v)
                        : null,
                  ),
                  _SwitchTile(
                    key: const Key('notif_event_feed_photo'),
                    title: 'Foto no mural',
                    value: p.eventFeedPhoto,
                    onChanged: p.pushEnabled
                        ? (v) => controller.toggleEvent(feedPhoto: v)
                        : null,
                  ),
                  _SwitchTile(
                    key: const Key('notif_event_streak_risk'),
                    title: 'Streak em risco',
                    value: p.eventStreakRisk,
                    onChanged: p.pushEnabled
                        ? (v) => controller.toggleEvent(streakRisk: v)
                        : null,
                  ),
                  _SwitchTile(
                    key: const Key('notif_event_streak_broken'),
                    title: 'Streak quebrado',
                    value: p.eventStreakBroken,
                    onChanged: p.pushEnabled
                        ? (v) => controller.toggleEvent(streakBroken: v)
                        : null,
                  ),
                  _SwitchTile(
                    key: const Key('notif_event_shop_purchase'),
                    title: 'Compra na loja',
                    value: p.eventShopPurchase,
                    onChanged: p.pushEnabled
                        ? (v) => controller.toggleEvent(shopPurchase: v)
                        : null,
                  ),
                ],
              ),
              if (controller.status == NotifSettingsStatus.error &&
                  controller.error != null) ...[
                const SizedBox(height: NinhoSpacing.stackMd),
                Text(
                  controller.error!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: NinhoColors.error,
                      ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: NinhoColors.onSurface,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: NinhoColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(NinhoRadii.xl),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14944931),
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final disabled = onChanged == null;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: NinhoSpacing.paddingCard,
        vertical: 12,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: disabled
                            ? NinhoColors.onSurfaceVariant
                            : NinhoColors.onSurface,
                      ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: NinhoColors.onSurfaceVariant,
                        ),
                  ),
                ],
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: NinhoColors.primary,
          ),
        ],
      ),
    );
  }
}

class _TimeTile extends StatelessWidget {
  const _TimeTile({
    required this.keyValue,
    required this.label,
    required this.minutes,
    required this.enabled,
    required this.onPick,
  });

  final String keyValue;
  final String label;
  final int minutes;
  final bool enabled;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final formatted =
        '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
    return InkWell(
      key: Key(keyValue),
      borderRadius: BorderRadius.circular(NinhoRadii.regular),
      onTap: enabled ? () => _pick(context) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: NinhoSpacing.paddingCard,
          vertical: 14,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: enabled
                          ? NinhoColors.onSurface
                          : NinhoColors.onSurfaceVariant,
                    ),
              ),
            ),
            Text(
              formatted,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: enabled
                        ? NinhoColors.primary
                        : NinhoColors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              color: enabled
                  ? NinhoColors.onSurfaceVariant
                  : NinhoColors.outlineVariant,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pick(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
    );
    if (picked == null) return;
    onPick(picked.hour * 60 + picked.minute);
  }
}
