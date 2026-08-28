import 'package:flutter/material.dart';
import 'package:notel/notes_provider.dart';
import 'package:provider/provider.dart';

class CategoryDrawer extends StatelessWidget {
  const CategoryDrawer({super.key});

  void _showCreateCategoryDialog(BuildContext context, NotesProvider provider) {
    final textController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('New Category'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: textController,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Category name',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Category name is required';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                final name = textController.text.trim();
                final category = await provider.createCategory(name);
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
                if (context.mounted && category != null) {
                  await provider.setSelectedCategory(category);
                  if (context.mounted) {
                    Navigator.pop(context); // close drawer
                  }
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NotesProvider>(
      builder: (context, provider, child) {
        return Drawer(
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Categories',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        tooltip: 'New category',
                        onPressed: () => _showCreateCategoryDialog(context, provider),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.notes),
                  title: const Text('All notes'),
                  selected: provider.selectedCategory == null,
                  onTap: () async {
                    await provider.clearSelectedCategory();
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
                Expanded(
                  child: provider.categories.isEmpty
                      ? const Center(
                          child: Text(
                            'No categories yet',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: provider.categories.length,
                          itemBuilder: (context, index) {
                            final category = provider.categories[index];
                            final isSelected = provider.selectedCategory?.id == category.id;
                            return ListTile(
                              leading: const Icon(Icons.folder_outlined),
                              title: Text(category.name),
                              selected: isSelected,
                              onTap: () async {
                                await provider.setSelectedCategory(category);
                                if (context.mounted) Navigator.pop(context);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
