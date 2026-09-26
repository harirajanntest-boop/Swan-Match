/**
 * Swan AI — LLM narratives via Groq (dev) or OpenAI (prod).
 * Scores stay rule-based in the Flutter app; this module only writes text.
 */
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret, defineString } = require('firebase-functions/params');
const OpenAI = require('openai');
const admin = require('firebase-admin');

const groqApiKey = defineSecret('GROQ_API_KEY');
const aiProvider = defineString('AI_PROVIDER', { default: 'groq' });
const openaiModel = defineString('OPENAI_MODEL', { default: 'gpt-4o-mini' });
const groqModel = defineString('GROQ_MODEL', {
  default: 'llama-3.3-70b-versatile',
});

const SYSTEM_COMPAT = `You are Swan AI, a marriage-compatibility coach for a serious marriage platform (not casual dating).
Write warm, specific, respectful insights for two people preparing for marriage.
Use only the structured profile fields and scores provided — do not invent facts.
Never encourage casual dating, sexual content, or unsafe behavior.
Return valid JSON only.`;

function providerName() {
  return String(aiProvider.value() || process.env.AI_PROVIDER || 'groq')
    .trim()
    .toLowerCase();
}

function buildClient() {
  const provider = providerName();
  if (provider === 'openai') {
    // Production: set OPENAI_API_KEY in Functions env / Secret Manager, then
    // add it to this function's `secrets` array (see SWAN_AI.md).
    const key = process.env.OPENAI_API_KEY || '';
    if (!key) {
      throw new HttpsError(
        'failed-precondition',
        'OPENAI_API_KEY is not configured. Set the secret or use AI_PROVIDER=groq.',
      );
    }
    return {
      provider: 'openai',
      model: String(openaiModel.value() || 'gpt-4o-mini'),
      client: new OpenAI({ apiKey: key }),
    };
  }

  const key =
    process.env.GROQ_API_KEY ||
    (typeof groqApiKey.value === 'function' ? groqApiKey.value() : '');
  if (!key) {
    throw new HttpsError(
      'failed-precondition',
      'GROQ_API_KEY is not configured.',
    );
  }
  return {
    provider: 'groq',
    model: String(groqModel.value() || 'llama-3.3-70b-versatile'),
    client: new OpenAI({
      apiKey: key,
      baseURL: 'https://api.groq.com/openai/v1',
    }),
  };
}

function extractJson(text) {
  if (!text || typeof text !== 'string') return null;
  const trimmed = text.trim();
  try {
    return JSON.parse(trimmed);
  } catch (_) {
    const start = trimmed.indexOf('{');
    const end = trimmed.lastIndexOf('}');
    if (start >= 0 && end > start) {
      try {
        return JSON.parse(trimmed.slice(start, end + 1));
      } catch (__) {
        return null;
      }
    }
    return null;
  }
}

async function chatJson({ system, user, temperature = 0.5 }) {
  const { client, model, provider } = buildClient();
  const completion = await client.chat.completions.create({
    model,
    temperature,
    max_tokens: 700,
    response_format: { type: 'json_object' },
    messages: [
      { role: 'system', content: system },
      { role: 'user', content: user },
    ],
  });
  const content = completion.choices?.[0]?.message?.content || '';
  const parsed = extractJson(content);
  if (!parsed) {
    throw new HttpsError('internal', 'LLM returned non-JSON content.');
  }
  return { parsed, provider, model };
}

function assertAuth(request) {
  if (!request.auth?.uid) {
    throw new HttpsError('unauthenticated', 'Sign in required.');
  }
  return request.auth.uid;
}

/**
 * Video-first redesign: replaces assertJourneyParticipant. The only use of
 * the old journeyId was reading the journeys doc to authorize that the
 * caller is one of its two participants — no journey-stage-specific content
 * was ever read here — so this is a straight repoint onto
 * connections/{connectionId}, checking membership via senderId/receiverId
 * instead of a userIds array.
 */
async function assertConnectionParticipant(uid, connectionId) {
  if (!connectionId || typeof connectionId !== 'string') {
    throw new HttpsError('invalid-argument', 'connectionId is required.');
  }
  const snap = await admin.firestore().collection('connections').doc(connectionId).get();
  if (!snap.exists) {
    throw new HttpsError('not-found', 'Connection not found.');
  }
  const data = snap.data() || {};
  if (data.senderId !== uid && data.receiverId !== uid) {
    throw new HttpsError('permission-denied', 'Not a connection participant.');
  }
  return data;
}

function firstName(profile, fallback) {
  if (!profile || typeof profile !== 'object') return fallback;
  const n = (profile.firstName || profile.name || '').toString().trim();
  return n || fallback;
}

function compactProfile(profile) {
  if (!profile || typeof profile !== 'object') return {};
  const mp = profile.marriageProfile && typeof profile.marriageProfile === 'object'
    ? profile.marriageProfile
    : {};
  const intent = mp.intent && typeof mp.intent === 'object' ? mp.intent : {};
  const lifestyle =
    mp.lifestyleValues && typeof mp.lifestyleValues === 'object'
      ? mp.lifestyleValues
      : {};
  return {
    firstName: firstName(profile, ''),
    age: profile.age ?? null,
    religion: profile.religion || '',
    lookingFor: profile.lookingFor || '',
    marriageTimeline: intent.marriageTimeline || profile.marriageTimeline || '',
    childrenPreference: lifestyle.childrenPreference || '',
    financialStyle: lifestyle.financialStyle || '',
    familyImportance: lifestyle.familyImportance || '',
    decisionMakingStyle: lifestyle.decisionMakingStyle || '',
    communicationStyle: profile.communicationStyle || '',
    preferredLifestyle: profile.preferredLifestyle || '',
  };
}

/**
 * Callable: enrich a rule-based compatibility report with LLM narrative.
 * Input: { connectionId, nameA, nameB, overallScore, ratingTier, categoryScores,
 *          strengths, discussionTopics, profileA, profileB }
 */
exports.generateCompatibilityNarrative = onCall(
  {
    secrets: [groqApiKey],
    timeoutSeconds: 60,
    memory: '512MiB',
  },
  async (request) => {
    const uid = assertAuth(request);
    const data = request.data || {};
    await assertConnectionParticipant(uid, data.connectionId);

    const nameA = String(data.nameA || 'Partner A').slice(0, 40);
    const nameB = String(data.nameB || 'Partner B').slice(0, 40);
    const overallScore = Number(data.overallScore) || 0;
    const ratingTier = String(data.ratingTier || 'Match');
    const categoryScores =
      data.categoryScores && typeof data.categoryScores === 'object'
        ? data.categoryScores
        : {};
    const strengths = Array.isArray(data.strengths) ? data.strengths.slice(0, 6) : [];
    const discussionTopics = Array.isArray(data.discussionTopics)
      ? data.discussionTopics.slice(0, 6)
      : [];

    const userPrompt = JSON.stringify(
      {
        task: 'Write a marriage compatibility narrative',
        pair: { nameA, nameB },
        ruleScores: { overallScore, ratingTier, categoryScores },
        seedStrengths: strengths,
        seedTopics: discussionTopics,
        profileA: compactProfile(data.profileA),
        profileB: compactProfile(data.profileB),
        outputSchema: {
          personalizedSummary:
            '2-3 sentences naming both people and why they align for marriage',
          strengths: 'array of 3-4 short strength labels',
          discussionTopics: 'array of 2-3 concrete discussion topics',
        },
      },
      null,
      2,
    );

    try {
      const { parsed, provider, model } = await chatJson({
        system: SYSTEM_COMPAT,
        user: userPrompt,
      });

      const summary = String(
        parsed.personalizedSummary || parsed.summary || '',
      ).trim();
      const outStrengths = Array.isArray(parsed.strengths)
        ? parsed.strengths.map((s) => String(s).trim()).filter(Boolean).slice(0, 4)
        : strengths;
      const outTopics = Array.isArray(parsed.discussionTopics)
        ? parsed.discussionTopics.map((s) => String(s).trim()).filter(Boolean).slice(0, 3)
        : discussionTopics;

      if (!summary) {
        throw new HttpsError('internal', 'LLM omitted personalizedSummary.');
      }

      return {
        personalizedSummary: summary.slice(0, 800),
        strengths: outStrengths,
        discussionTopics: outTopics,
        provider,
        model,
      };
    } catch (e) {
      if (e instanceof HttpsError) throw e;
      console.error('[generateCompatibilityNarrative]', e?.message || e);
      throw new HttpsError(
        'internal',
        e?.message || 'Failed to generate compatibility narrative.',
      );
    }
  },
);
