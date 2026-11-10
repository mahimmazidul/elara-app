/// General menstrual-health information, bundled with the app.
///
/// This is education, not assessment. Nothing here is chosen from the user's
/// cycle data, and no topic is ever shown *because* of a phase or a logged
/// symptom — the reader opens the section and picks what is relevant to them.
/// That separation is deliberate: personalized care is on Today, where it can
/// carry its own evidence and caveats, and this file is the background reading
/// behind it.
///
/// Every topic lists the sources it was written from and the month they were
/// checked, so a reader can see how current it is. Elara makes no claim that a
/// clinician has reviewed this text; see `docs/` for that limitation.
library;

/// One reference behind a topic.
class MedicalSource {
  const MedicalSource(this.label, this.url);

  /// Who published it and what it covers.
  final String label;

  /// Full URL. Shows as selectable text and copies to the clipboard, because
  /// the app does not depend on a browser launcher.
  final String url;
}

/// A heading with body text inside a topic.
class MedicalSection {
  const MedicalSection(this.heading, this.paragraphs, {this.bullets = const []});

  final String heading;
  final List<String> paragraphs;
  final List<String> bullets;
}

/// One subject a reader can open.
class MedicalTopic {
  const MedicalTopic({
    required this.id,
    required this.title,
    required this.summary,
    required this.sections,
    required this.whenToSeekHelp,
    required this.sources,
    this.urgentNote,
  });

  final String id;
  final String title;

  /// One or two sentences for the list, so the screen is scannable.
  final String summary;

  final List<MedicalSection> sections;

  /// The red-flag list. Every topic has one, and it is never hidden behind a
  /// tap: it is the most useful part of the page.
  final List<String> whenToSeekHelp;

  /// A safety line that must be shown prominently, where one applies.
  final String? urgentNote;

  final List<MedicalSource> sources;
}

/// When the sources below were last checked by hand.
const String medicalSourcesChecked = 'November 2026';

/// The standing caveat printed at the top of every topic.
const String medicalDisclaimer =
    'General information, not medical advice about you. Elara does not '
    'diagnose anything, and none of this is selected from your cycle data.';

const List<MedicalTopic> medicalTopics = [
  MedicalTopic(
    id: 'period-pain',
    title: 'Period pain (dysmenorrhoea)',
    summary:
        'Cramping around the start of a period is one of the most common '
        'menstrual symptoms. Pain that stops ordinary activity is not '
        '"just something to put up with".',
    sections: [
      MedicalSection(
        'What it usually feels like',
        [
          'The typical pattern is a dull, cramping ache low in the abdomen, '
              'often starting on the first day or two of bleeding and easing '
              'within a few days. It can spread to the lower back and thighs, '
              'and may come with headache, nausea, loose stools or tiredness.',
        ],
      ),
      MedicalSection(
        'Two broad patterns clinicians distinguish',
        [
          'Primary dysmenorrhoea is period pain without an identifiable '
              'underlying condition. It is very common, especially in the '
              'years after periods begin, and is linked to prostaglandins — '
              'chemicals that make the uterus contract.',
          'Secondary dysmenorrhoea is pain caused by something else, such as '
              'endometriosis, fibroids or an infection. It is more likely if '
              'the pain started later in life, is getting worse, lasts longer '
              'than the bleed, or does not respond to ordinary pain relief.',
          'Telling these apart is a clinical judgement. It is not something '
              'an app can do, and Elara does not try.',
        ],
      ),
      MedicalSection(
        'Things people commonly try',
        [
          'Heat on the lower abdomen, gentle movement, and rest help some '
              'people. Over-the-counter pain relief taken early in the bleed '
              'works better than waiting for the pain to build; see the '
              'pain-relief topic for precautions.',
        ],
        bullets: [
          'A heat pack or warm bath',
          'Regular, light activity rather than complete rest',
          'Pain relief started at the first sign of cramping',
        ],
      ),
    ],
    whenToSeekHelp: [
      'Pain that regularly stops you going to work, study or school',
      'Pain that is getting worse cycle after cycle, or started after years '
          'of manageable periods',
      'Pain with heavy bleeding, bleeding between periods, or pain during sex',
      'Pain with fever, unusual discharge, or a sudden severe pain',
      'Pain that does not improve with over-the-counter pain relief',
    ],
    sources: [
      MedicalSource('NHS — Period pain',
          'https://www.nhs.uk/conditions/period-pain/'),
      MedicalSource('ACOG — Dysmenorrhea: painful periods',
          'https://www.acog.org/womens-health/faqs/dysmenorrhea-painful-periods'),
    ],
  ),
  MedicalTopic(
    id: 'heavy-bleeding',
    title: 'Heavy or prolonged bleeding',
    summary:
        'Heavy menstrual bleeding is common and treatable. The point at which '
        'bleeding counts as heavy is about how much it affects your life, not '
        'only how many days it lasts.',
    sections: [
      MedicalSection(
        'What clinicians usually ask about',
        [
          'Rather than a millilitre count, the useful questions are practical: '
              'are you changing protection every hour or two, passing clots '
              'larger than a coin, bleeding for more than seven days, or '
              'getting up in the night to change?',
          'Heavy bleeding over time can cause iron-deficiency anaemia, which '
              'brings its own tiredness, breathlessness and pallor. That is '
              'one reason it is worth mentioning rather than enduring.',
        ],
      ),
      MedicalSection(
        'Possible causes',
        [
          'Common causes include fibroids, endometrial polyps, '
              'adenomyosis, thyroid problems, bleeding disorders and '
              'hormonal changes around puberty and perimenopause. Often no '
              'cause is found.',
          'Which one applies is decided by examination and tests, not by a '
              'calendar pattern.',
        ],
      ),
    ],
    whenToSeekHelp: [
      'Changing pads or tampons every hour for several hours',
      'Passing clots larger than a 50-pence or rupee coin',
      'Bleeding that lasts longer than seven days',
      'Bleeding between periods, or after sex',
      'Any bleeding after the menopause',
      'Feeling faint, very breathless, or unusually tired — see someone '
          'sooner rather than waiting',
    ],
    urgentNote:
        'Soaking through protection in under an hour, with dizziness or '
        'fainting, needs urgent medical attention rather than a wait-and-see '
        'approach.',
    sources: [
      MedicalSource('NHS — Heavy periods',
          'https://www.nhs.uk/conditions/heavy-periods/'),
      MedicalSource('NICE guideline NG88 — Heavy menstrual bleeding',
          'https://www.nice.org.uk/guidance/ng88'),
      MedicalSource('ACOG — Heavy menstrual bleeding',
          'https://www.acog.org/womens-health/faqs/heavy-menstrual-bleeding'),
    ],
  ),
  MedicalTopic(
    id: 'irregular-periods',
    title: 'Irregular periods',
    summary:
        'Cycle length varies between people and between months. "Irregular" is '
        'a description of a pattern, not a diagnosis.',
    sections: [
      MedicalSection(
        'What variation is ordinary',
        [
          'Adult cycles commonly fall somewhere between about 21 and 35 days, '
              'and a few days of variation from month to month is normal. '
              'Cycles are often less regular in the first years after periods '
              'start, and more variable again in the years before menopause.',
          'Short-term changes often follow illness, travel, major stress, '
              'significant weight change, or a change in contraception.',
        ],
      ),
      MedicalSection(
        'When a pattern is worth investigating',
        [
          'Frequent very short cycles, gaps of several months, or bleeding '
              'that has become unpredictable after being regular are worth '
              'raising. Conditions such as thyroid disorders, PCOS and '
              'perimenopause can present this way, and so can pregnancy.',
          'An app can only describe the dates you recorded. It cannot tell '
              'you why they moved, and a predicted date is not a measurement.',
        ],
      ),
    ],
    whenToSeekHelp: [
      'Cycles consistently shorter than 21 days or longer than 35 days',
      'Gaps of three months or more when you are not pregnant',
      'Bleeding between periods or after sex',
      'A sudden change in a previously regular pattern',
      'Any bleeding after the menopause',
    ],
    sources: [
      MedicalSource('NHS — Irregular periods',
          'https://www.nhs.uk/conditions/irregular-periods/'),
      MedicalSource('NHS — Periods',
          'https://www.nhs.uk/conditions/periods/'),
      MedicalSource('WHO — Menstrual health',
          'https://www.who.int/news-room/fact-sheets/detail/menstrual-health'),
    ],
  ),
  MedicalTopic(
    id: 'pms',
    title: 'Premenstrual syndrome (PMS)',
    summary:
        'Physical and emotional symptoms in the one to two weeks before a '
        'period, easing once bleeding starts. Common, and manageable for most '
        'people.',
    sections: [
      MedicalSection(
        'The pattern that matters',
        [
          'PMS is defined by its timing: symptoms that appear in the luteal '
              'phase and resolve within a few days of the period starting. '
              'Symptoms that are present all month are not PMS, even if they '
              'feel worse before a period.',
          'Tracking for two or three cycles is the usual first step, because '
              'the pattern is the evidence. Elara can hold those notes, but '
              'interpreting them is a conversation with a clinician.',
        ],
      ),
      MedicalSection(
        'What is commonly reported',
        [
          'Bloating, breast tenderness, headaches, fatigue, food cravings, '
              'irritability, low mood, anxiety and difficulty concentrating '
              'are all frequently described. The list is long and individual '
              'patterns vary widely.',
        ],
      ),
      MedicalSection(
        'Generally suggested approaches',
        [
          'Regular sleep, steady activity, and cutting back on alcohol and '
              'caffeine help some people. Calcium and vitamin B6 supplements '
              'are sometimes suggested; ask a pharmacist or clinician before '
              'starting anything, and mention any other medicines you take.',
        ],
      ),
    ],
    whenToSeekHelp: [
      'Symptoms that interfere with work, relationships or daily life',
      'Symptoms that are getting worse over time',
      'Low mood, anxiety or irritability that is severe or frightening',
      'Symptoms that do not follow a premenstrual pattern',
      'Any thoughts of harming yourself — seek help urgently, today',
    ],
    sources: [
      MedicalSource('NHS — Premenstrual syndrome',
          'https://www.nhs.uk/conditions/pre-menstrual-syndrome/'),
      MedicalSource('ACOG — Premenstrual syndrome',
          'https://www.acog.org/womens-health/faqs/premenstrual-syndrome'),
    ],
  ),
  MedicalTopic(
    id: 'pmdd',
    title: 'Premenstrual dysphoric disorder (PMDD)',
    summary:
        'A severe form of premenstrual symptoms where mood symptoms dominate '
        'and interfere substantially with life. It needs clinical assessment.',
    sections: [
      MedicalSection(
        'How it differs from PMS',
        [
          'In PMDD the emotional symptoms — marked depression, irritability, '
              'anxiety, a sense of being overwhelmed — are the central feature '
              'and are severe enough to disrupt work and relationships. '
              'Physical symptoms may be present too.',
          'Like PMS, it follows the cycle: symptoms in the premenstrual week, '
              'relief shortly after bleeding begins, and a clear week in '
              'between. That pattern usually needs to be documented across at '
              'least two cycles before a diagnosis is considered.',
        ],
      ),
      MedicalSection(
        'What to do with a suspicion',
        [
          'Keep a daily note of mood and cycle dates for two or three months, '
              'then bring it to a clinician. Elara can store the notes; it '
              'cannot confirm or rule out PMDD, and it will not suggest that '
              'you have it.',
        ],
      ),
    ],
    whenToSeekHelp: [
      'Mood symptoms in the premenstrual week that disrupt work or '
          'relationships',
      'Feeling hopeless, worthless or unable to cope in the premenstrual week',
      'Any thoughts of self-harm or suicide — seek urgent help immediately',
    ],
    urgentNote:
        'If you are having thoughts of harming yourself, contact emergency '
        'services or a crisis line now. That is not something to wait a cycle '
        'to see whether it passes.',
    sources: [
      MedicalSource('NHS — Premenstrual syndrome (includes PMDD)',
          'https://www.nhs.uk/conditions/pre-menstrual-syndrome/'),
      MedicalSource('ACOG — Premenstrual syndrome',
          'https://www.acog.org/womens-health/faqs/premenstrual-syndrome'),
    ],
  ),
  MedicalTopic(
    id: 'pcos',
    title: 'Polycystic ovary syndrome (PCOS)',
    summary:
        'A common hormonal condition with varied features: irregular periods, '
        'signs of excess androgens, and polycystic ovaries on ultrasound. '
        'Diagnosis requires clinical assessment.',
    sections: [
      MedicalSection(
        'What the name does and does not mean',
        [
          '"Polycystic" refers to small follicles visible on an ultrasound '
              'scan, not to cysts in the usual sense. Having polycystic-looking '
              'ovaries alone does not mean someone has PCOS.',
          'Features vary a great deal between people: some have irregular or '
              'absent periods, some have acne or increased hair growth, some '
              'have neither and are investigated for another reason.',
        ],
      ),
      MedicalSection(
        'Why an app cannot diagnose it',
        [
          'Assessment combines history, examination, blood tests and sometimes '
              'an ultrasound, and other causes of irregular periods have to be '
              'excluded first. An irregular cycle pattern recorded in an app '
              'is one clue among several — never a diagnosis, and never '
              'something Elara will suggest on its own.',
        ],
      ),
      MedicalSection(
        'Why it is worth raising',
        [
          'PCOS is associated with difficulty conceiving, type 2 diabetes and '
              'cardiovascular risk, so a diagnosis opens the door to monitoring '
              'and support. Weight management, where relevant, and specific '
              'medication are decisions made with a clinician.',
        ],
      ),
    ],
    whenToSeekHelp: [
      'Periods that are consistently irregular or absent',
      'Rapid onset of acne or increased facial or body hair',
      'Difficulty conceiving after a year of trying, or six months if over 35',
      'Symptoms of high blood sugar, such as excessive thirst or urination',
    ],
    sources: [
      MedicalSource('NHS — Polycystic ovary syndrome',
          'https://www.nhs.uk/conditions/polycystic-ovary-syndrome-pcos/'),
      MedicalSource('WHO — Polycystic ovary syndrome fact sheet',
          'https://www.who.int/news-room/fact-sheets/detail/polycystic-ovary-syndrome'),
      MedicalSource('ACOG — Polycystic ovary syndrome (PCOS)',
          'https://www.acog.org/womens-health/faqs/polycystic-ovary-syndrome-pcos'),
    ],
  ),
  MedicalTopic(
    id: 'endometriosis',
    title: 'Endometriosis',
    summary:
        'Tissue similar to the uterine lining growing outside the uterus. A '
        'common cause of severe period pain, and one that is often diagnosed '
        'late.',
    sections: [
      MedicalSection(
        'Why it is mentioned here',
        [
          'Endometriosis is one of the conditions behind secondary '
              'dysmenorrhoea — period pain that is severe, worsening, or not '
              'controlled by ordinary pain relief. It can also cause pain '
              'during sex, pain passing stools during a period, and difficulty '
              'conceiving.',
          'It is listed here as background reading, not as a suggestion about '
              'anyone using this app. Only a clinician can investigate it.',
        ],
      ),
      MedicalSection(
        'Assessment',
        [
          'Diagnosis usually starts with a history and examination, and may '
              'involve imaging or, in some cases, laparoscopy. Keeping a record '
              'of when pain occurs — including whether it is tied to bleeding '
              'at all — is genuinely useful in that conversation.',
        ],
      ),
    ],
    whenToSeekHelp: [
      'Period pain severe enough to stop normal activity, repeatedly',
      'Pain during or after sex',
      'Pain opening the bowels or passing urine during a period',
      'Difficulty conceiving',
    ],
    sources: [
      MedicalSource('NHS — Endometriosis',
          'https://www.nhs.uk/conditions/endometriosis/'),
      MedicalSource('NICE guideline NG73 — Endometriosis',
          'https://www.nice.org.uk/guidance/ng73'),
    ],
  ),
  MedicalTopic(
    id: 'common-symptoms',
    title: 'Common symptoms, and what is usually harmless',
    summary:
        'Short notes on the symptoms this app lets you record, so a note in '
        'the log can be read in context rather than as an alarm.',
    sections: [
      MedicalSection(
        'Usually manageable, and common',
        [
          'Cramps, headache, fatigue, bloating, nausea, breast tenderness and '
              'mood changes are all frequently reported around a period. Their '
              'presence does not indicate a problem, and their absence does '
              'not indicate that anything is wrong either.',
        ],
      ),
      MedicalSection(
        'Features that change the picture',
        [
          'Severity matters more than presence: a symptom that regularly stops '
              'daily life is worth raising even if the symptom itself is '
              'common. So is a symptom that is new, one-sided, or comes with '
              'fever.',
        ],
        bullets: [
          'Sudden severe abdominal pain, especially one-sided',
          'Pain with fever, or with unusual or foul-smelling discharge',
          'Fainting, dizziness, or very heavy bleeding together',
          'Symptoms that persist through the whole cycle rather than around '
              'the period',
        ],
      ),
    ],
    whenToSeekHelp: [
      'Any symptom that is severe, sudden, or rapidly worsening',
      'Pain with fever',
      'Symptoms that keep returning over several cycles',
      'Anything that frightens you — that is reason enough to ask',
    ],
    sources: [
      MedicalSource('NHS — Periods',
          'https://www.nhs.uk/conditions/periods/'),
      MedicalSource('NHS — Period pain',
          'https://www.nhs.uk/conditions/period-pain/'),
    ],
  ),
  MedicalTopic(
    id: 'pain-relief',
    title: 'Over-the-counter pain relief: precautions',
    summary:
        'General safety notes on the painkillers most often used for period '
        'pain. What suits someone is a decision for them, a pharmacist or a '
        'clinician — not something an app infers from a cycle phase.',
    sections: [
      MedicalSection(
        'The usual options',
        [
          'Paracetamol and non-steroidal anti-inflammatory drugs (NSAIDs) such '
              'as ibuprofen are the common choices. NSAIDs are often more '
              'effective for period pain because they reduce prostaglandins, '
              'but they are not suitable for everyone. Mefenamic acid is an '
              'NSAID sometimes prescribed for period pain.',
          'Read the packet and follow the label. Do not take two products that '
              'contain the same ingredient — many cold and flu remedies '
              'contain paracetamol.',
        ],
      ),
      MedicalSection(
        'Precautions worth knowing',
        [
          'NSAIDs can irritate the stomach and are usually avoided by people '
              'with a stomach ulcer, kidney problems, or a history of asthma '
              'triggered by aspirin or NSAIDs. They are generally avoided in '
              'later pregnancy. Paracetamol is often preferred in pregnancy, '
              'but the dose limits matter: exceeding them can damage the '
              'liver.',
          'Aspirin should not be given to children under 16.',
        ],
        bullets: [
          'Check for existing conditions before starting an NSAID',
          'Check for interactions with anything else being taken',
          'Keep to the maximum daily dose, and count combined products',
          'Ask a pharmacist if pregnant, breastfeeding, or unsure',
        ],
      ),
    ],
    whenToSeekHelp: [
      'Pain that over-the-counter medicine does not touch',
      'Stomach pain, black stools, or vomiting blood while taking an NSAID',
      'Anyone who has taken more than the stated dose — contact a poison '
          'service or emergency care immediately',
    ],
    urgentNote:
        'A suspected overdose is an emergency, even if you feel well. Contact '
        'emergency services or a poison information service straight away.',
    sources: [
      MedicalSource('NHS — Paracetamol for adults',
          'https://www.nhs.uk/medicines/paracetamol-for-adults/'),
      MedicalSource('NHS — Ibuprofen for adults',
          'https://www.nhs.uk/medicines/ibuprofen-for-adults/'),
    ],
  ),
];
