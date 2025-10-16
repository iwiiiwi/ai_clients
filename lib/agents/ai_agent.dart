import 'dart:convert';

import 'package:ai_clients/ai_clients.dart';
import 'package:ai_clients/logging/logging.dart';
import 'package:mcp_llm/mcp_llm.dart' as llm;

class AiAgent {
  final AiClient client;
  final List<Tool> tools;
  final String description;
  final Logger _logger;

  final List<Message> _history;

  AiAgent({
    required this.client,
    required this.description,
    this.tools = const [],
    Logger? logger,
    List<Message>? history,
  })  : _history = history ?? [],
        _logger = logger ?? Logger() {
    _logger.agentLog(
      LogLevel.debug,
      'Agent initialized',
      agentName: runtimeType.toString(),
    );
  }

  Stream<Message> sendMessageStream(Message message,
      {List<Context> context = const []}) async* {
    Stream<llm.LlmResponseChunk> response = client.streamQuery(
      system: description,
      history: _history,
      message: message,
      contexts: context,
      tools: tools,
      delay: client.delay,
    );

    await for (final chunk in response) {
      print("=========== chunk:${jsonEncode(chunk)}");
      if (chunk.isDone) {
         yield Message.assistant(chunk.textChunk,);

        addIntoHistory(
          message.type == MessageType.toolResult
              ? message
              : Message(
                  type: message.type,
                  content:
                      buildPrompt(prompt: message.content, contexts: context),
                ),
        );

        final Message responseMessage;

        if (chunk.toolCalls?.isNotEmpty ?? false) {
          addIntoHistory(Message.toolCall(chunk.textChunk));
          List toolCalls = [];
          chunk.toolCalls!.forEach((t) {
            toolCalls.add({
              'function':{
 'name': t.name,
              'arguments': t.arguments,
              'id':t.id,
              },
              'name':t.name,
             'id':t.id,
            });
          });

          final toolCallMessages =
              await client.makeToolCalls(tools: tools, toolCalls: toolCalls);
          final lastMessage = toolCallMessages.removeLast();
          _history.addAll(toolCallMessages);
          if (!lastMessage.noNeedForAi) {
            responseMessage = await sendMessage(lastMessage);
          } else {
            responseMessage = Message.assistant(chunk.textChunk);
          }
        } else {
          responseMessage = Message.assistant(chunk.textChunk);
          addIntoHistory(responseMessage);
        }

        yield responseMessage;
      }
    }
  }

  Future<Message> sendMessage(Message message,
      {List<Context> context = const []}) async {
    AiClientResponse response = await client.query(
      system: description,
      history: _history,
      message: message,
      contexts: context,
      tools: tools,
      delay: client.delay,
    );

    addIntoHistory(
      message.type == MessageType.toolResult
          ? message
          : Message(
              type: message.type,
              content: buildPrompt(prompt: message.content, contexts: context),
            ),
    );

    final Message responseMessage;

    if (response is ToolResponse) {
      addIntoHistory(Message.toolCall(response.rawMessage!));

      final toolCalls = (jsonDecode(response.rawMessage!) as List);

      final toolCallMessages =
          await client.makeToolCalls(tools: tools, toolCalls: toolCalls);
      final lastMessage = toolCallMessages.removeLast();
      _history.addAll(toolCallMessages);
      if (!lastMessage.noNeedForAi) {
        responseMessage = await sendMessage(lastMessage);
      } else {
        responseMessage = Message.assistant(response.message ?? "");
      }
    } else {
      responseMessage = Message.assistant(response.message!);
      addIntoHistory(responseMessage);
    }

    return responseMessage;
  }

  void addIntoHistory(Message message) {
    _history.add(message);

    _logger.agentLog(
      LogLevel.debug,
      message.toString(),
      agentName: runtimeType.toString(),
    );
  }

  void clearHistory() {
    _history.clear();
  }

  void showHistory() {
    print(_history);
  }
}
