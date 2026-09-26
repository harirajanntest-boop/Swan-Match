# Swan AI (Groq / OpenAI)

Hybrid setup: **rule-based scores** in Flutter + **LLM narratives** in Cloud Functions.

| Environment | Provider | Model (default) |
|-------------|----------|-----------------|
| Development | Groq | `llama-3.3-70b-versatile` |
| Production | OpenAI | `gpt-4o-mini` |

Provider is controlled by Functions param `AI_PROVIDER` (`groq` | `openai`). Default: **groq**.

## Callables

- `generateCompatibilityNarrative` — enriches AI Match Explanation text
- `generateJourneyStageInsight` — Journey stage insight cards

## Set Groq secret (required now)

```bash
cd functions
printf '%s' 'YOUR_GROQ_KEY' | firebase functions:secrets:set GROQ_API_KEY --project swan-match
```

Params live in `functions/.env` (gitignored):

```text
AI_PROVIDER=groq
OPENAI_MODEL=gpt-4o-mini
GROQ_MODEL=llama-3.3-70b-versatile
```

## Deploy AI functions

This project uses codebase `mobile-backend`:

```bash
cd functions
npm install
npx firebase-tools@latest deploy --only functions:mobile-backend:generateCompatibilityNarrative,functions:mobile-backend:generateJourneyStageInsight --project swan-match
```

## Switch to OpenAI later (production)

1. Create secret:
   ```bash
   printf '%s' 'YOUR_OPENAI_KEY' | firebase functions:secrets:set OPENAI_API_KEY --project swan-match
   ```
2. Update [`swan_ai.js`](swan_ai.js) so both callables include `openaiApiKey` in `secrets: [...]` (see comments in file).
3. Set `AI_PROVIDER=openai` and redeploy.

## Security

- Never put Groq/OpenAI keys in the Flutter app or git.
- Callables require auth + journey participant check.
- On LLM failure, the app falls back to rule-based copy.

## Flutter wiring

- [`lib/services/swan_ai_service.dart`](../lib/services/swan_ai_service.dart)
- [`lib/services/compatibility_service.dart`](../lib/services/compatibility_service.dart) — version `2.0-hybrid-llm`
- [`lib/services/journey_service.dart`](../lib/services/journey_service.dart) — `LlmAIInsightProvider` default
