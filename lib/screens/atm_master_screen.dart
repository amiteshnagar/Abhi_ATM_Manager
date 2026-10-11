import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/transaction_provider.dart';
import '../widgets/glass_card.dart';

class ATMMasterScreen extends ConsumerWidget {
  const ATMMasterScreen({super.key});

  void _showAddATMDialog(BuildContext context, WidgetRef ref) {
    final formKey = GlobalKey<FormState>();
    final idController = TextEditingController();
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add ATM Unit'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: idController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'ATM ID',
                    hintText: 'e.g., ATM05',
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter ATM ID.';
                    }
                    if (val.trim().length < 3) {
                      return 'ATM ID must be at least 3 characters.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'ATM Name / Location',
                    hintText: 'e.g., Pachore Main',
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter location name.';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                
                final id = idController.text.trim().toUpperCase();
                final name = nameController.text.trim();
                
                final list = ref.read(atmListProvider);
                final exists = list.any((atm) => atm['id'] == id);
                if (exists) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('An ATM with this ID already exists.')),
                  );
                  return;
                }

                await ref.read(atmListProvider.notifier).addATM(id, name);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('ATM Unit added successfully.')),
                  );
                  Navigator.pop(context);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _deleteATM(BuildContext context, WidgetRef ref, String id) async {
    final defaultAtms = {'ABHI01', 'ATM02', 'ATM03', 'ATM04'};
    if (defaultAtms.contains(id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Default ATM units cannot be deleted.')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete ATM Unit'),
        content: Text('Are you sure you want to delete ATM unit $id? This will not delete past transactions logged under it, but it will remove it from the dropdown.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[600]),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(atmListProvider.notifier).deleteATM(id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ATM Unit deleted successfully.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final atms = ref.watch(atmListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ATM Master'),
      ),
      body: atms.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.atm_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No ATM units registered.',
                    style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey[500]),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: atms.length,
              itemBuilder: (context, index) {
                final atm = atms[index];
                final id = atm['id']!;
                final name = atm['name']!;
                final isDefault = {'ABHI01', 'ATM02', 'ATM03', 'ATM04'}.contains(id);

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: GlassCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
                          child: Icon(Icons.atm, color: theme.colorScheme.primary),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                id,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                name,
                                style: TextStyle(color: Colors.grey[600], fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        if (isDefault)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Default',
                              style: TextStyle(
                                color: theme.colorScheme.secondary,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        else
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _deleteATM(context, ref, id),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        onPressed: () => _showAddATMDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }
}
