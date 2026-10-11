import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants.dart';
import '../../../core/theme.dart';
import '../../state/auth_state.dart';
import '../../state/bag_state.dart';
import '../../state/sync_state.dart';
import '../../widgets/waste_category_picker.dart';

class CreateBagScreen extends StatefulWidget {
  const CreateBagScreen({super.key});

  @override
  State<CreateBagScreen> createState() => _CreateBagScreenState();
}

class _CreateBagScreenState extends State<CreateBagScreen> {
  Set<WasteCategory> _selected = {WasteCategory.plastic};
  double _weightKg = 2.5;
  final _notesController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick at least one category')),
      );
      return;
    }
    setState(() => _saving = true);

    final ownerId = context.read<AuthState>().currentUser!.id;
    final bagState = context.read<BagState>();
    final sync = context.read<SyncState>();
    final notes = _notesController.text.trim();

    // A local SQLite write plus an outbox entry. It completes almost
    // instantly whatever the network is doing.
    await bagState.createBag(
      ownerId: ownerId,
      categories: _selected.toList(),
      weightKg: _weightKg,
      notes: notes.isEmpty ? null : notes,
    );

    sync.triggerSync();
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Bag')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text("What's inside?", style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: AppSpacing.sm),
              WasteCategoryPicker(
                categories: bagCategories,
                selected: _selected,
                onChanged: (s) => setState(() => _selected = s),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text('Estimated weight', style: Theme.of(context).textTheme.labelLarge),
              Text(
                '${_weightKg.toStringAsFixed(1)} kg',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              Slider(
                value: _weightKg,
                min: 0.5,
                max: 15,
                divisions: 145,
                activeColor: AppColors.primaryGreen,
                onChanged: (v) => setState(() => _weightKg = v),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  hintText: 'e.g. rinsed containers',
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              ElevatedButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
                    : const Text('Create & get tag'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}