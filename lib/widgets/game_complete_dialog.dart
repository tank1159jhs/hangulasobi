import 'package:flutter/material.dart';

class GameCompleteDialog extends StatelessWidget {
  final int score;
  final int perfectCount;
  final int goodCount;
  final int missCount;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  const GameCompleteDialog({
    required this.score,
    required this.perfectCount,
    required this.goodCount,
    required this.missCount,
    required this.onRetry,
    required this.onBack,
  });

  int get _accuracy {
    final total = perfectCount + goodCount + missCount;
    return total > 0 ? (((perfectCount + goodCount) / total) * 100).toInt() : 0;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        '🎉 完了！',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '合計: $scoreポイント',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          _buildResultRow('🎯 完璧', perfectCount),
          _buildResultRow('👍 良い', goodCount),
          _buildResultRow('❌ ミス', missCount),
          const SizedBox(height: 10),
          Text(
            '正確度: $_accuracy%',
            style: const TextStyle(fontSize: 18, color: Colors.purple),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: onBack,
          child: const Text('戻る'),
        ),
        ElevatedButton(
          onPressed: onRetry,
          child: const Text('もう一度'),
        ),
      ],
    );
  }

  Widget _buildResultRow(String label, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text('$count', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
