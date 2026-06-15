import 'package:cloud_functions/cloud_functions.dart';

/// Thin wrapper around the `proxyGroqChat` Firebase callable function.
///
/// All Groq API calls in the app go through this class so the API key
/// never exists in the client binary.
class GroqService {
  static final _fn =
      FirebaseFunctions.instance.httpsCallable('proxyGroqChat');

  /// Calls the Groq chat-completions endpoint via the server-side proxy.
  ///
  /// [model]       — Groq model ID (e.g. 'llama-3.3-70b-versatile')
  /// [messages]    — OpenAI-compatible messages array
  /// [maxTokens]   — max tokens to generate (default 1024)
  /// [temperature] — sampling temperature (default 0.3)
  ///
  /// Returns the assistant message content string.
  /// Throws [FirebaseFunctionsException] on error (network, auth, Groq failure).
  static Future<String> chat({
    required String model,
    required List<Map<String, dynamic>> messages,
    int maxTokens = 1024,
    double temperature = 0.3,
  }) async {
    final result = await _fn.call<Map<dynamic, dynamic>>({
      'model': model,
      'messages': messages,
      'maxTokens': maxTokens,
      'temperature': temperature,
    });
    return result.data['content'] as String;
  }
}
