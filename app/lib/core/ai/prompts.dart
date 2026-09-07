/// Prompts and schemas travel with the request. The worker forwards them
/// unchanged and never repairs the model’s JSON.
library;

const kJournalSystem = '''
You extract structured health-log items from one journal entry for a
general fitness app (running, riding, swimming, team sports, mobility,
climbing, martial arts, gym sets, food, sleep, body mass — not gym-only).

Return JSON only, matching the schema.
Rules:
- Prefer stated numbers. Do not invent precise calories, pace, distance or
  heart rate; mark those estimates.
- Gym lifts belong in sets (exercise, kg, reps). Do not also invent a gym
  activity unless they named a timed session ("gym 45 min").
- Endurance belongs in activities: discipline, distance, minutes, pace if
  given ("5k in 24:30" → run, 5 km, 24.5 min, pace 4:54/km).
- Name effort when they did: easy, steady, tempo, intervals, race, long.
- Sports and mobility belong in activities with minutes ("football 90 min",
  "yoga 45", "played rugby 80").
- Derive pace from distance + time when both are present.
- Never include advice. Never echo the raw entry as a field.
- If they said how the night felt (poorly, restless, well, deep), set
  sleep.quality from 0 (poor) to 1 (well). Do not invent a quality.
- If nothing structured is present, return empty arrays.
''';

const kDayDigestSystem = '''
You write one instrument sentence about a day of movement, intake and sleep.
Cover whatever actually happened — a run, a ride, a match, a lift, a rest.
No advice. No second person coaching. No exclamation. At most 140 characters.
If the figures cannot support a sentence, return an empty sentence.
''';

const kJournalSchema = <String, Object?>{
  'type': 'object',
  'additionalProperties': false,
  'properties': {
    'sets': {
      'type': 'array',
      'items': {
        'type': 'object',
        'properties': {
          'exercise': {'type': 'string'},
          'weightKg': {'type': 'number'},
          'reps': {'type': 'integer'},
          'sets': {'type': 'integer'},
          'rpe': {'type': 'number'},
        },
        'required': ['exercise', 'weightKg', 'reps'],
      },
    },
    'foods': {
      'type': 'array',
      'items': {
        'type': 'object',
        'properties': {
          'label': {'type': 'string'},
          'kcal': {'type': 'number'},
          'proteinG': {'type': 'number'},
          'carbsG': {'type': 'number'},
          'fatG': {'type': 'number'},
          'estimate': {'type': 'boolean'},
        },
        'required': ['label', 'kcal'],
      },
    },
    'activities': {
      'type': 'array',
      'items': {
        'type': 'object',
        'properties': {
          'discipline': {'type': 'string'},
          'label': {'type': 'string'},
          'kcal': {'type': 'number'},
          'minutes': {'type': 'number'},
          'distanceKm': {'type': 'number'},
          'distanceM': {'type': 'number'},
          'miles': {'type': 'number'},
          'pace': {'type': 'string'},
          'rpe': {'type': 'number'},
          'hr': {'type': 'number'},
          'effort': {
            'type': 'string',
            'enum': ['easy', 'steady', 'tempo', 'intervals', 'race', 'long'],
          },
          'estimate': {'type': 'boolean'},
        },
        'required': ['label'],
      },
    },
    'sleep': {
      'type': 'object',
      'properties': {
        'startHours': {'type': 'number'},
        'endHours': {'type': 'number'},
        'quality': {'type': 'number'},
      },
    },
    'weightKg': {'type': 'number'},
  },
};

const kDayDigestSchema = <String, Object?>{
  'type': 'object',
  'additionalProperties': false,
  'properties': {
    'sentence': {'type': 'string'},
  },
  'required': ['sentence'],
};

const kPatternInsightSystem = '''
You write at most two instrument sentences about findings that already
survived statistical gates. The findings are the only facts. Do not invent
pairs, numbers, or causes. No advice. No second person. No exclamation.
Never ask for more data. If the findings cannot support a sentence, return
an empty sentence.
''';

const kPatternInsightSchema = kDayDigestSchema;
