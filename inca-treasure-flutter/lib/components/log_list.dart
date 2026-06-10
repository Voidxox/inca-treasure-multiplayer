import 'package:flutter/material.dart';
import '../theme/colors.dart';

class LogList extends StatelessWidget {
  const LogList({super.key, required this.logs});

  final List<Map<String, String>> logs;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 172,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: .1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.history_rounded, color: gold, size: 17),
              SizedBox(width: 6),
              Text(
                '探险记录',
                style: TextStyle(color: bone, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: logs.isEmpty
                ? const Center(
                    child: Text(
                      '暂无记录',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                  )
                : Scrollbar(
                    thumbVisibility: true,
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: logs.length,
                      itemBuilder: (context, index) {
                        final text = logs[index]['text'] ?? '';
                        return Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(right: 8, bottom: 7),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .045),
                            borderRadius: BorderRadius.circular(8),
                            border: const Border(
                              left: BorderSide(color: gold, width: 2),
                            ),
                          ),
                          child: Text(
                            text,
                            style: const TextStyle(color: muted, fontSize: 12),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
