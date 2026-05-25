import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/users_repository.dart';
import '../../../data/services/room_photo_service.dart';
import '../../core/colors.dart';
import '../../core/spacing.dart';
import 'account_settings_controller.dart';

// Sub-tela de "Editar perfil" — sem Stitch dedicado no projeto.
// Visual segue tokens canônicos (DESIGN.md). Cobre avatar (JPG, EXIF strip
// via ImagePickerRoomPhotoService) + display_name.
class EditProfileScreen extends StatelessWidget {
  const EditProfileScreen({
    super.key,
    this.usersRepository,
    this.photoService,
  });

  final UsersRepository? usersRepository;
  final RoomPhotoService? photoService;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AccountSettingsController>(
      create: (_) =>
          AccountSettingsController(usersRepository: usersRepository)..load(),
      child: _View(photoService: photoService),
    );
  }
}

class _View extends StatefulWidget {
  const _View({this.photoService});
  final RoomPhotoService? photoService;

  @override
  State<_View> createState() => _ViewState();
}

class _ViewState extends State<_View> {
  late final RoomPhotoService _photoService =
      widget.photoService ?? ImagePickerRoomPhotoService();
  final _nameController = TextEditingController();
  bool _initialized = false;
  bool _uploadingAvatar = false;
  bool _savingName = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _maybeSeedName(AccountSettingsController ctrl) {
    if (_initialized) return;
    final name = ctrl.profile?.displayName;
    if (name != null) {
      _nameController.text = name;
      _initialized = true;
    }
  }

  Future<void> _pickAvatar(
    BuildContext context,
    AccountSettingsController ctrl,
    RoomPhotoSource source,
  ) async {
    if (_uploadingAvatar) return;
    setState(() => _uploadingAvatar = true);
    try {
      final draft = await _photoService.pickAndPrepare(source);
      if (draft == null) {
        setState(() => _uploadingAvatar = false);
        return;
      }
      final ok = await ctrl.uploadAvatar(draft.bytes);
      if (!context.mounted) return;
      if (!ok && ctrl.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ctrl.error!)),
        );
      }
    } on RoomPhotoValidationException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Falha ao escolher a imagem.')),
      );
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _removeAvatar(
    BuildContext context,
    AccountSettingsController ctrl,
  ) async {
    if (_uploadingAvatar) return;
    setState(() => _uploadingAvatar = true);
    final ok = await ctrl.removeAvatar();
    if (mounted) setState(() => _uploadingAvatar = false);
    if (!context.mounted) return;
    if (!ok && ctrl.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ctrl.error!)),
      );
    }
  }

  Future<void> _saveName(
    BuildContext context,
    AccountSettingsController ctrl,
  ) async {
    final text = _nameController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Digite seu nome.')),
      );
      return;
    }
    setState(() => _savingName = true);
    final ok = await ctrl.updateDisplayName(text);
    if (mounted) setState(() => _savingName = false);
    if (!context.mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil atualizado.')),
      );
      context.pop();
    } else if (ctrl.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ctrl.error!)),
      );
    }
  }

  void _openSourceSheet(
    BuildContext context,
    AccountSettingsController ctrl,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: NinhoColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('avatar_pick_camera'),
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tirar foto'),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _pickAvatar(context, ctrl, RoomPhotoSource.camera);
              },
            ),
            ListTile(
              key: const Key('avatar_pick_gallery'),
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Escolher da galeria'),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _pickAvatar(context, ctrl, RoomPhotoSource.gallery);
              },
            ),
            if (ctrl.profile?.avatarPath != null)
              ListTile(
                key: const Key('avatar_remove'),
                leading: const Icon(Icons.delete_outline, color: NinhoColors.error),
                title: const Text(
                  'Remover foto',
                  style: TextStyle(color: NinhoColors.error),
                ),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  _removeAvatar(context, ctrl);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<AccountSettingsController>();
    _maybeSeedName(ctrl);
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: NinhoColors.background,
      appBar: AppBar(
        backgroundColor: NinhoColors.background,
        elevation: 0,
        leading: IconButton(
          key: const Key('edit_profile_back'),
          icon: const Icon(Icons.arrow_back, color: NinhoColors.onSurface),
          onPressed: () => context.canPop() ? context.pop() : context.go('/profile/account'),
        ),
        centerTitle: true,
        title: Text(
          'Editar perfil',
          style: theme.textTheme.titleMedium?.copyWith(
            color: NinhoColors.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: ctrl.status == AccountSettingsStatus.loading
            ? const Center(
                child: CircularProgressIndicator(color: NinhoColors.primary),
              )
            : ListView(
                padding: const EdgeInsets.all(NinhoSpacing.marginMobile),
                children: [
                  Center(
                    child: _AvatarPicker(
                      url: ctrl.avatarSignedUrl,
                      uploading: _uploadingAvatar,
                      onTap: () => _openSourceSheet(context, ctrl),
                      fallbackLetter: _initialOf(ctrl.profile?.displayName),
                    ),
                  ),
                  const SizedBox(height: NinhoSpacing.stackLg),
                  Text(
                    'Nome',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: NinhoColors.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: NinhoSpacing.stackSm),
                  TextField(
                    key: const Key('edit_profile_name'),
                    controller: _nameController,
                    maxLength: 80,
                    decoration: const InputDecoration(
                      hintText: 'Como quer ser chamado(a)?',
                    ),
                  ),
                  const SizedBox(height: NinhoSpacing.stackLg),
                  FilledButton(
                    key: const Key('edit_profile_save'),
                    onPressed: _savingName ? null : () => _saveName(context, ctrl),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: _savingName
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Salvar'),
                  ),
                ],
              ),
      ),
    );
  }

  String _initialOf(String? name) {
    final s = name?.trim();
    if (s == null || s.isEmpty) return '?';
    return s.characters.first.toUpperCase();
  }
}

class _AvatarPicker extends StatelessWidget {
  const _AvatarPicker({
    required this.url,
    required this.uploading,
    required this.onTap,
    required this.fallbackLetter,
  });

  final String? url;
  final bool uploading;
  final VoidCallback onTap;
  final String fallbackLetter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        GestureDetector(
          key: const Key('edit_profile_avatar'),
          onTap: uploading ? null : onTap,
          child: Container(
            width: 128,
            height: 128,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: NinhoColors.secondaryContainer,
              image: url != null
                  ? DecorationImage(
                      image: NetworkImage(url!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            alignment: Alignment.center,
            child: url == null
                ? Text(
                    fallbackLetter,
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: NinhoColors.onSecondaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : null,
          ),
        ),
        if (uploading)
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x66000000),
              ),
              child: Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              ),
            ),
          ),
        if (!uploading)
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: NinhoColors.primary,
            ),
            child: const Icon(
              Icons.camera_alt_outlined,
              color: Colors.white,
              size: 22,
            ),
          ),
      ],
    );
  }
}
