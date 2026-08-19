import '../models/donation_type.dart';

/// Educational copy shown from the Home Learn affordance and Settings.
class DonationTypeInfo {
  const DonationTypeInfo({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  static DonationTypeInfo forType(DonationType type) => switch (type) {
        DonationType.wholeBlood => wholeBlood,
        DonationType.plasma => plasma,
        DonationType.platelet => platelet,
        DonationType.doubleRed => doubleRed,
      };

  static const wholeBlood = DonationTypeInfo(
    title: 'Whole Blood Donation',
    body:
        'Whole Blood Donation is the most common type, collecting approximately one pint of blood '
        'that is separated into red cells, plasma, and platelets. It is best for first-time donors '
        'and helps trauma patients, surgical recipients, and those with anemia.\n\n'
        'Side effects include temporary fatigue due to lowered red cell volume, which the body '
        'replenishes over days to weeks. Health benefits for donors include improved blood flow, '
        'lower iron levels (reducing heart disease risk), and potential detoxification effects.\n\n'
        'Donations can be made every 56 to 84 days, with a shelf life of 42 days.',
  );

  static const plasma = DonationTypeInfo(
    title: 'Plasma Donation',
    body:
        'Plasma Donation (plasmapheresis) collects only the liquid part of the blood, returning '
        'red cells and platelets to the donor. This type is critical for patients with severe burns, '
        'trauma, shock, or clotting disorders, and is especially valuable for donors with AB blood types.\n\n'
        'Side effects may include bleeding, bruising, dehydration, dizziness, and fainting. '
        'The body replenishes plasma quickly, allowing donations about every 28 days (around 4 weeks). '
        'Plasma has a short shelf life of 5–7 days and is often used to manufacture medications or '
        'treat infections via antibodies.',
  );

  static const platelet = DonationTypeInfo(
    title: 'Platelet Donation (Apheresis)',
    body:
        'Platelet donation, or plateletpheresis, is an automated process where blood is drawn from '
        'the donor, passed through a machine that separates and collects only the platelets, and '
        'returns the remaining red blood cells and plasma to the donor. This method allows a single '
        'donation to yield enough platelets for up to three patients, unlike whole blood which must '
        'be pooled from multiple donors. The process typically takes 1.5 to 3 hours and requires the '
        'use of an anticoagulant (citrate) to prevent clotting in the machine. Donors can give as '
        'often as every 7 days, up to 24 times a year, because the body replenishes platelets rapidly.\n\n'
        'Approximate volume logged in this app: ~250 ml platelet concentrate per donation '
        '(centers vary; this is only for personal totals).\n\n'
        'Center-specific notes (check with your donation center — not medical advice)\n\n'
        'Many centers ask platelet donors to avoid aspirin and similar medications for a period '
        'before donation (often about 48 hours), because they can affect platelet function. Rules '
        'vary by organization — always confirm with your center.\n\n'
        'Side effects\n\n'
        'While generally safe, platelet donation has specific side effects distinct from whole blood:\n\n'
        '• Citrate reaction: the most common specific side effect is caused by the anticoagulant '
        'citrate, which temporarily binds to calcium in the donor’s blood. Symptoms include tingling '
        'or numbness around the lips, fingers, or toes, a metallic taste, chills, or muscle cramps. '
        'These are usually mild and resolved by slowing the donation rate or taking calcium '
        'supplements (e.g., Tums).\n\n'
        '• Fatigue and dizziness: though less common than in whole blood donation (since red cells '
        'are returned), some donors may still feel lightheaded or tired.\n\n'
        '• Bruising: pain, swelling, or bruising at the needle site can occur, particularly because '
        'the donation duration is longer.\n\n'
        '• Vasovagal reactions: rare instances of fainting or nausea may occur, especially in '
        'first-time donors.\n\n'
        'Health benefits\n\n'
        '• Reduced clotting risk (for high counts): for donors with naturally high platelet counts '
        '(thrombocytosis), regular donation can help lower the risk of blood clots and stroke by '
        'maintaining a safer platelet level.\n\n'
        '• Removal of toxins: similar to plasma donation, platelet donation removes a portion of '
        'plasma, which can help reduce levels of PFAS (“forever chemicals”) and microplastics that '
        'bind to blood proteins, though potentially less efficiently than pure plasma donation since '
        'some plasma is returned.\n\n'
        '• Cardiovascular health: some evidence suggests that regular donation may improve blood '
        'flow and reduce blood viscosity, potentially lowering the risk of heart attack, although '
        'this benefit is more strongly associated with whole blood donation.\n\n'
        '• Free health screening: donors receive a mini-physical at every visit, including checks '
        'for blood pressure, pulse, temperature, and hemoglobin/platelet counts, providing regular '
        'health monitoring.\n\n'
        '• Psychological well-being: the act of donating provides a significant psychological boost, '
        'reducing stress and improving emotional well-being through the knowledge of directly saving '
        'lives, particularly for cancer patients.',
  );

  static const doubleRed = DonationTypeInfo(
    title: 'Double Red Cell Donation (Power Red)',
    body:
        'Often chosen after experience with whole blood. Donation centers set their own eligibility — '
        'this app does not lock Double Red behind prior donations.\n\n'
        'Double Red Cell Donation (Power Red) uses apheresis to collect two units of concentrated '
        'red blood cells while returning plasma and platelets to the donor. It is ideal for donors '
        'with O, A, or B negative types and helps patients with sickle cell anemia, severe blood loss, '
        'or those needing multiple transfusions.\n\n'
        'Center-specific notes (check with your donation center — not medical advice)\n\n'
        'Power Red often has stricter height, weight, and hemoglobin thresholds than whole blood. '
        'Requirements differ by center and sex/gender policies. Confirm eligibility with staff before '
        'you go — this app only tracks your personal dates.\n\n'
        'Soft journey tip: after a successful whole blood donation or two, some donors explore Double '
        'Red as a higher-impact option. It is advisory only; you can switch types anytime.\n\n'
        'Donors may experience tingling sensations from anticoagulants (often eased with calcium) or '
        'fatigue, though saline replacement often reduces post-donation tiredness. This donation '
        'doubles the impact per visit but requires a longer deferral period of 112 days (every 16 weeks).',
  );

  /// Brief center-rule notes shown from Settings (not medical advice).
  static const centerRuleNotes = DonationTypeInfo(
    title: 'Center-specific rules',
    body:
        'Donation centers set their own eligibility. This app does not enforce medical rules — '
        'always check with your center.\n\n'
        'Platelets\n'
        '• Many centers restrict aspirin (and similar medications) for a period before platelet '
        'donation (often ~48 hours). Confirm the exact window with your center.\n\n'
        'Double Red / Power Red\n'
        '• Often requires higher height, weight, and hemoglobin thresholds than whole blood. '
        'Criteria vary; ask staff before scheduling.\n\n'
        'Whole blood & plasma\n'
        '• Intervals, travel deferrals, and health screens vary by organization and location.\n\n'
        'This is educational framing only — not medical advice.',
  );

  /// Soft donor-journey guidance (also surfaced as a Home hint).
  static const donorJourneyGuidance = DonationTypeInfo(
    title: 'Donor journey (soft guidance)',
    body:
        'Suggested order is Whole Blood → Plasma / Platelets → Double Red (Power Red). '
        'Labels like “Start here” and “Advanced” are guidance only.\n\n'
        'After one or two successful whole blood donations, some people consider Double Red as a '
        'higher-impact option when they meet their center’s criteria. Nothing in this app is locked — '
        'you can log any type at any time.',
  );

  /// PFAS / toxins overview — linked from Settings so Home stays uncluttered.
  static const pfasAndToxins = DonationTypeInfo(
    title: 'About donation types / PFAS & toxins',
    body:
        'Removal of “forever chemicals” (PFAS)\n\n'
        'The most significant evidence for toxin removal involves Per- and Polyfluoroalkyl Substances '
        '(PFAS), known as “forever chemicals” due to their persistence in the environment and the '
        'human body. A landmark clinical trial involving Australian firefighters found that regular '
        'donation significantly lowers PFAS levels:\n\n'
        '• Plasma donation was the most effective method, reducing serum PFAS concentrations by '
        'approximately 30% over a 12-month period. This is because PFAS bind to proteins found '
        'primarily in the blood serum.\n\n'
        '• Whole blood donation also reduced PFAS levels, though to a lesser extent (about 10% '
        'reduction), as it removes both serum and red blood cells.\n\n'
        '• Platelet (apheresis) donation removes some plasma along with platelets and may help reduce '
        'PFAS and similar protein-bound substances, but it is generally less efficient than pure '
        'plasma donation because a portion of plasma is returned to the donor.\n\n'
        '• Mechanism: since these chemicals bind to serum proteins, removing plasma physically '
        'extracts the toxins from the bloodstream, speeding up the body’s natural elimination process.\n\n'
        'Removal of heavy metals and excess iron\n\n'
        '• Excess iron: donating blood removes oxidized iron, which can otherwise accumulate and '
        'cause cellular damage or hinder the liver’s ability to filter other toxins. This is '
        'particularly beneficial for individuals with hemochromatosis (iron overload).\n\n'
        '• Heavy metals: small amounts of circulating heavy metals (such as lead, cadmium, and '
        'mercury) are removed along with the blood cells and plasma. While the body naturally '
        'eliminates these slowly over time, donation provides a faster route for removing the '
        'fraction circulating in the blood at the time of donation. However, experts note that '
        'donation is not a primary treatment for acute metal poisoning.\n\n'
        'Important considerations\n\n'
        '• Not a general “detox”: donation does not replace the liver or kidneys in filtering '
        'general metabolic waste. Its toxin-removal benefit is specific to substances that bind '
        'to blood components (like PFAS to serum proteins or iron to red cells).\n\n'
        '• Frequency matters: the reduction in toxins like PFAS is linked to regular donation '
        '(for example, every few weeks for plasma, or as often as weekly for platelets) rather than '
        'a single event, as the body can re-accumulate these chemicals from the environment.\n\n'
        'This information is educational only and is not medical advice. Always follow your '
        'donation center’s eligibility rules.',
  );
}
