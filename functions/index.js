// BrainUp Firebase Cloud Functions
// Proxies Groq API calls so the API key never leaves the server.

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');

const groqApiKey = defineSecret('GROQ_API_KEY');

/**
 * proxyGroqChat — authenticated callable function.
 *
 * Request data:
 *   model       {string}  Groq model ID
 *   messages    {Array}   OpenAI-compatible messages array
 *   maxTokens   {number}  max_tokens for the completion (default 1024)
 *   temperature {number}  sampling temperature (default 0.3)
 *
 * Returns:
 *   { content: string }   — the assistant message content
 *
 * Throws HttpsError('unauthenticated') if the caller is not signed in.
 */
exports.proxyGroqChat = onCall(
  { secrets: [groqApiKey], region: 'us-central1' },
  async (request) => {
    // Reject unauthenticated callers.
    if (!request.auth) {
      throw new HttpsError(
        'unauthenticated',
        'You must be signed in to use AI features.',
      );
    }

    const { model, messages, maxTokens = 1024, temperature = 0.3 } =
      request.data;

    if (!model || !Array.isArray(messages) || messages.length === 0) {
      throw new HttpsError(
        'invalid-argument',
        'model and messages are required.',
      );
    }

    const response = await fetch(
      'https://api.groq.com/openai/v1/chat/completions',
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${groqApiKey.value()}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          model,
          messages,
          max_tokens: maxTokens,
          temperature,
        }),
      },
    );

    if (!response.ok) {
      const errorText = await response.text();
      console.error(`Groq error ${response.status}: ${errorText}`);
      throw new HttpsError(
        'internal',
        `Groq API returned ${response.status}. Please try again.`,
      );
    }

    const data = await response.json();
    const content = data?.choices?.[0]?.message?.content;
    if (typeof content !== 'string') {
      throw new HttpsError('internal', 'Unexpected response shape from Groq.');
    }
    return { content };
  },
);
