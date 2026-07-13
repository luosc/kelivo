import 'dart:convert';

class ClaudeMessageTransformer {
  const ClaudeMessageTransformer._();

  static List<Map<String, dynamic>> normalizeToolHistoryMessages(
    List<Map<String, dynamic>> messages,
  ) {
    final out = <Map<String, dynamic>>[];
    final pendingToolResults = <Map<String, dynamic>>[];

    void flushPendingToolResults() {
      if (pendingToolResults.isEmpty) return;
      out.add({
        'role': 'user',
        'content': List<Map<String, dynamic>>.from(pendingToolResults),
      });
      pendingToolResults.clear();
    }

    for (final original in messages) {
      final message = Map<String, dynamic>.from(original);
      final role = (message['role'] ?? 'user').toString();
      if (role == 'tool') {
        final id = (message['tool_call_id'] ?? '').toString();
        if (id.startsWith('srvtoolu_') ||
            _hasCompleteServerToolBlocks(message, id)) {
          continue;
        }
        if (id.isNotEmpty) {
          pendingToolResults.add({
            'type': 'tool_result',
            'tool_use_id': id,
            'content': (message['content'] ?? '').toString(),
          });
        }
        continue;
      }

      flushPendingToolResults();
      if (role == 'assistant' && message['tool_calls'] is List) {
        final toolCalls = message['tool_calls'] as List;
        if (_isLegacyServerToolCallGroup(toolCalls)) continue;
        final blocks =
            _anthropicBlocksFromToolCallMetadata(toolCalls) ??
            <Map<String, dynamic>>[];
        if (blocks.isEmpty) {
          final text = (message['content'] ?? '').toString();
          if (text.trim().isNotEmpty && text.trim() != '\n\n') {
            blocks.add({'type': 'text', 'text': text});
          }
          for (final toolCall in toolCalls) {
            if (toolCall is! Map) continue;
            final block = _toolUseBlockFromToolCall(toolCall);
            if (block != null) blocks.add(block);
          }
        }
        if (blocks.isNotEmpty) {
          out.add({'role': 'assistant', 'content': blocks});
        }
        continue;
      }

      message['role'] = role.isEmpty ? 'user' : role;
      out.add(message);
    }

    flushPendingToolResults();
    return out;
  }

  static Map<String, dynamic>? _toolUseBlockFromToolCall(Map toolCall) {
    final id = (toolCall['id'] ?? '').toString();
    final fn = toolCall['function'];
    if (id.isEmpty || fn is! Map) return null;
    Map<String, dynamic> input = const <String, dynamic>{};
    try {
      input = (jsonDecode((fn['arguments'] ?? '{}').toString()) as Map)
          .cast<String, dynamic>();
    } catch (_) {}
    return {
      'type': 'tool_use',
      'id': id,
      'name': (fn['name'] ?? '').toString(),
      'input': input,
    };
  }

  static Set<String> _toolUseIdsInBlocks(List<Map<String, dynamic>> blocks) {
    return blocks
        .where((block) {
          final type = block['type'];
          return type == 'tool_use' || type == 'server_tool_use';
        })
        .map((block) => (block['id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  static bool _hasCompleteServerToolBlocks(Map message, String id) {
    final meta = message['metadata'];
    if (meta is! Map) return false;
    final anthropic = meta['anthropic'];
    if (anthropic is! Map || anthropic['assistant_blocks_complete'] != true) {
      return false;
    }
    final blocks = anthropic['assistant_blocks'];
    if (blocks is! List) return false;
    final hasUse = blocks.whereType<Map>().any(
      (block) =>
          block['type'] == 'server_tool_use' &&
          (block['id'] ?? '').toString() == id,
    );
    final hasResult = blocks.whereType<Map>().any(
      (block) =>
          (block['type'] ?? '').toString().endsWith('_tool_result') &&
          (block['tool_use_id'] ?? '').toString() == id,
    );
    return hasUse && hasResult;
  }

  static bool _isLegacyServerToolCallGroup(List toolCalls) {
    final mappedCalls = toolCalls.whereType<Map>().toList();
    final serverCalls = mappedCalls.where((toolCall) {
      return (toolCall['id'] ?? '').toString().startsWith('srvtoolu_');
    }).toList();
    if (serverCalls.isEmpty || serverCalls.length != mappedCalls.length) {
      return false;
    }
    return serverCalls.any((toolCall) {
      final id = (toolCall['id'] ?? '').toString();
      return !_hasCompleteServerToolBlocks(toolCall, id);
    });
  }

  static List<Map<String, dynamic>>? _anthropicBlocksFromToolCallMetadata(
    List toolCalls,
  ) {
    final expectedIds = toolCalls
        .whereType<Map>()
        .map((toolCall) => (toolCall['id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toSet();
    List<Map<String, dynamic>>? bestBlocks;
    var bestMatchCount = -1;

    for (final toolCall in toolCalls) {
      if (toolCall is! Map) continue;
      final meta = toolCall['metadata'];
      if (meta is! Map) continue;
      final anthropic = meta['anthropic'];
      if (anthropic is! Map) continue;
      final blocks = anthropic['assistant_blocks'];
      if (blocks is! List || blocks.isEmpty) continue;
      final candidate = blocks
          .whereType<Map>()
          .map((block) => block.cast<String, dynamic>())
          .toList();
      final markedComplete = anthropic['assistant_blocks_complete'] == true;
      final hasThinkingBlock = candidate.any((block) {
        final type = (block['type'] ?? '').toString();
        return type == 'thinking' || type == 'redacted_thinking';
      });
      if (_hasUntrustedThinkingBlocks(candidate)) continue;
      if (hasThinkingBlock && !markedComplete) {
        continue;
      }
      final matchCount = _toolUseIdsInBlocks(
        candidate,
      ).where(expectedIds.contains).length;
      if (matchCount > bestMatchCount ||
          (matchCount == bestMatchCount &&
              candidate.length > (bestBlocks?.length ?? 0))) {
        bestBlocks = candidate;
        bestMatchCount = matchCount;
      }
    }
    if (bestBlocks == null) return null;
    if (expectedIds.isEmpty) return bestBlocks;

    final presentIds = _toolUseIdsInBlocks(bestBlocks);
    if (presentIds.containsAll(expectedIds)) return bestBlocks;

    final completed = <Map<String, dynamic>>[
      for (final block in bestBlocks) Map<String, dynamic>.from(block),
    ];
    for (final toolCall in toolCalls.whereType<Map>()) {
      final block = _toolUseBlockFromToolCall(toolCall);
      if (block == null) continue;
      final id = (block['id'] ?? '').toString();
      if (presentIds.contains(id)) continue;
      completed.add(block);
      presentIds.add(id);
    }
    return completed;
  }

  static bool _hasUntrustedThinkingBlocks(List<Map<String, dynamic>> blocks) {
    for (final block in blocks) {
      final type = (block['type'] ?? '').toString();
      if (type == 'thinking') {
        if (!block.containsKey('thinking')) return true;
        if ((block['signature'] ?? '').toString().isEmpty) return true;
      } else if (type == 'redacted_thinking') {
        if ((block['data'] ?? '').toString().isEmpty) return true;
      }
    }
    return false;
  }
}
