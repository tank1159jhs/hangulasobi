import 'package:flutter/material.dart';
import '../services/data_service.dart';
import '../models/korean_data.dart';

class PronunciationGuideDialog extends StatefulWidget {
  const PronunciationGuideDialog({super.key});

  @override
  State<PronunciationGuideDialog> createState() =>
      _PronunciationGuideDialogState();
}

class _PronunciationGuideDialogState extends State<PronunciationGuideDialog> {
  final DataService _dataService = DataService();
  List<HangulCharacter> _consonants = [];
  List<HangulCharacter> _vowels = [];
  bool _showConsonants = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final consonants = await _dataService.loadConsonants();
    final vowels = await _dataService.loadVowels();
    setState(() {
      _consonants = consonants;
      _vowels = vowels;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '発音ガイド / 발음 가이드',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            
            // 자음/모음 탭
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _showConsonants = true;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _showConsonants
                          ? Colors.pink.shade300
                          : Colors.grey.shade300,
                    ),
                    child: const Text('子音 / 자음'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _showConsonants = false;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: !_showConsonants
                          ? Colors.pink.shade300
                          : Colors.grey.shade300,
                    ),
                    child: const Text('母音 / 모음'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // 목록
            Expanded(
              child: ListView.builder(
                itemCount: _showConsonants
                    ? _consonants.length
                    : _vowels.length,
                itemBuilder: (context, index) {
                  final char = _showConsonants
                      ? _consonants[index]
                      : _vowels[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.pink.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            char.character,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      title: Text(
                        char.pronunciation,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        '読み方: ${char.sound}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  );
                },
              ),
            ),
            
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('閉じる / 닫기'),
            ),
          ],
        ),
      ),
    );
  }
}
