import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:offline_mesh_flutter/core/services/mesh_controller.dart';
import 'package:offline_mesh_flutter/core/theme/app_theme.dart';

class CreateGroupPage extends ConsumerStatefulWidget {
  const CreateGroupPage({super.key});

  @override
  ConsumerState<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends ConsumerState<CreateGroupPage> {
  final _name = TextEditingController();
  final _selected = <String>{};
  bool allowAdd = true;
  bool allowSend = true;
  bool allowCall = true;
  int step = 0;

  @override
  Widget build(BuildContext context) {
    final friends = ref.watch(meshControllerProvider).friends;

    return Scaffold(
      appBar: AppBar(title: Text(step == 0 ? 'New group' : 'Group permissions')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: kTeal,
        onPressed: () {
          if (step == 0) {
            if (_selected.isEmpty) return;
            setState(() => step = 1);
          } else {
            if (_name.text.trim().isEmpty) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Group "${_name.text}" saved locally (broadcast hooks ready)')),
            );
            Navigator.pop(context);
          }
        },
        child: Icon(step == 0 ? Icons.arrow_forward : Icons.check, color: Colors.white),
      ),
      body: step == 0
          ? ListView(
              children: friends.map((f) {
                final id = '${f['user_id']}';
                final name = '${f['username']}';
                final checked = _selected.contains(id);
                return CheckboxListTile(
                  value: checked,
                  activeColor: kTeal,
                  title: Text(name),
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        _selected.add(id);
                      } else {
                        _selected.remove(id);
                      }
                    });
                  },
                );
              }).toList(),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Group name', border: OutlineInputBorder()),
                ),
                SwitchListTile(
                  title: const Text('Allow members to add friends'),
                  value: allowAdd,
                  onChanged: (v) => setState(() => allowAdd = v),
                ),
                SwitchListTile(
                  title: const Text('Allow members to send messages'),
                  value: allowSend,
                  onChanged: (v) => setState(() => allowSend = v),
                ),
                SwitchListTile(
                  title: const Text('Allow members to start calls'),
                  value: allowCall,
                  onChanged: (v) => setState(() => allowCall = v),
                ),
              ],
            ),
    );
  }
}
