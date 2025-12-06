import 'package:flutter/material.dart';
import '../models/korean_data.dart';
import '../constants/app_constants.dart';

class SentenceListDialog extends StatefulWidget {
  final Map<String, List<KoreanSentence>> byCategory;

  const SentenceListDialog({required this.byCategory});

  @override
  State<SentenceListDialog> createState() => _SentenceListDialogState();
}

class _SentenceListDialogState extends State<SentenceListDialog> {
  String _selectedCategory = 'all';

  List<String> get _availableCategories {
    final set = <String>{'all'};
    set.addAll(byCategory.keys);
    final list = set.toList();
    list.sort();
    return list;
  }

  Map<String, List<KoreanSentence>> get byCategory => widget.byCategory;

  List<KoreanSentence> get _filteredSentences {
    if (_selectedCategory == 'all') {
      return [
        for (final list in byCategory.values) ...list,
      ];
    }
    return byCategory[_selectedCategory] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppBorderRadius.dialog),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxHeight: 600, maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '文章学習',
                  style: TextStyle(
                    fontSize: FontSizes.dialogTitle,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButton<String>(
              value: _selectedCategory,
              isExpanded: true,
              items: _availableCategories
                  .map(
                    (key) => DropdownMenuItem(
                      value: key,
                      child: Text(SentenceCategoryNames.get(key)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _selectedCategory = value;
                });
              },
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: _filteredSentences.length,
                itemBuilder: (context, index) {
                  final s = _filteredSentences[index];
                  return ListTile(
                    leading: Text(s.emoji, style: const TextStyle(fontSize: 24)),
                    title: Text(
                      s.sentence,
                      style: const TextStyle(
                        fontSize: FontSizes.itemTitle,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      s.meaning['ja'] ?? s.meaning['en'] ?? '',
                      style: const TextStyle(fontSize: FontSizes.itemSubtitle),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
