import 'package:ai_clients/models/tool.dart';

class AssistantResponse extends AiClientResponse {
  AssistantResponse(
      {required super.id, required super.message, super.role = 'assistant'});
}

class ToolResponse extends AiClientResponse {
  ToolResponse(
      {required super.id,
      required super.tools,
      super.role = 'tool',
      required super.rawMessage});
}

class ErrorResponse extends AiClientResponse {
  ErrorResponse(
      {  super.id="", 
      super.role = 'assistant', 
      super.isError=true,
      super.message,
      super.metadata,
      });
}

sealed class AiClientResponse {
  final String id;
  final String role;
  final String? message;
  final String? rawMessage;
  final Map<String, dynamic>? metadata;

  final List<Tool> tools;

  final bool isDone;

  final bool isError;

  const AiClientResponse(
      {required this.id,
      required this.role,
      this.message,
      this.rawMessage,
      this.tools = const [],
      this.isDone = true,
      this.isError=false,
      this.metadata,
      });

  @override
  String toString() {
    return 'AiClientResponse(id: $id, role: $role, message: $message, tools: $tools)';
  }
}
