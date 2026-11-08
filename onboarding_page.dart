import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:offline_mesh_flutter/core/crypto/identity.dart';
import 'package:offline_mesh_flutter/core/services/mesh_controller.dart';
import 'package:offline_mesh_flutter/core/theme/app_theme.dart';
import 'package:path_provider/path_provider.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _userCtrl = TextEditingController(text: randomUsername());
  final _bioCtrl = TextEditingController();
  int _step = 0;
  String? _avatarPath;

  @override
  void dispose() {
    _userCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512);
    if (file == null) return;
    final dir = await getApplicationDocumentsDirectory();
    final target = '${dir.path}/avatar_${DateTime.now().millisecondsSinceEpoch}.webp';
    final result = await FlutterImageCompress.compressAndGetFile(
      file.path,
      target,
      quality: 70,
      minWidth: 256,
      minHeight: 256,
      format: CompressFormat.webp,
    );
    if (result != null) {
      final len = await File(result.path).length();
      if (len > 40 * 1024) {
        // second pass
        final tighter = await FlutterImageCompress.compressAndGetFile(
          result.path,
          target,
          quality: 40,
          minWidth: 192,
          minHeight: 192,
          format: CompressFormat.webp,
        );
        setState(() => _avatarPath = tighter?.path ?? result.path);
      } else {
        setState(() => _avatarPath = result.path);
      }
    }
  }

  Future<void> _finish({bool skip = false}) async {
    final name = _userCtrl.text.trim();
    if (name.isEmpty) return;
    await ref.read(meshControllerProvider.notifier).completeOnboarding(
          username: name,
          bio: skip ? '' : _bioCtrl.text.trim(),
          avatarPath: skip ? null : _avatarPath,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _step == 0 ? _stepUsername() : _stepProfile(),
        ),
      ),
    );
  }

  Widget _stepUsername() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 40),
        const Icon(Icons.hub, size: 72, color: kTeal),
        const SizedBox(height: 16),
        Text('Mesh Chat', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Chat without internet', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
        const Spacer(),
        TextField(
          controller: _userCtrl,
          decoration: InputDecoration(
            labelText: 'Username',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            suffixIcon: IconButton(
              tooltip: 'Regenerate',
              onPressed: () => setState(() => _userCtrl.text = randomUsername()),
              icon: const Icon(Icons.refresh),
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: kTeal, minimumSize: const Size.fromHeight(48)),
          onPressed: () {
            if (_userCtrl.text.trim().isEmpty) return;
            setState(() => _step = 1);
          },
          child: const Text('Next'),
        ),
      ],
    );
  }

  Widget _stepProfile() {
    return Column(
      children: [
        const SizedBox(height: 24),
        GestureDetector(
          onTap: _pickAvatar,
          child: CircleAvatar(
            radius: 56,
            backgroundColor: kTeal.withValues(alpha: 0.15),
            backgroundImage: _avatarPath != null ? FileImage(File(_avatarPath!)) : null,
            child: _avatarPath == null ? const Icon(Icons.camera_alt, color: kTeal, size: 36) : null,
          ),
        ),
        const SizedBox(height: 8),
        const Text('Tap to add photo (compressed <40KB)'),
        const SizedBox(height: 24),
        TextField(
          controller: _bioCtrl,
          maxLength: 120,
          decoration: InputDecoration(
            labelText: 'Bio (optional)',
            hintText: 'Hey there! I am using Offline Mesh',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const Spacer(),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: kTeal, minimumSize: const Size.fromHeight(48)),
          onPressed: () => _finish(),
          child: const Text('Finish / Start'),
        ),
        TextButton(onPressed: () => _finish(skip: true), child: const Text('Skip')),
      ],
    );
  }
}
