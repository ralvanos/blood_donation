import 'package:blood_donation/models/donation_type.dart';
import 'package:blood_donation/models/eligibility_matrix.dart';
import 'package:blood_donation/models/typed_donation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EligibilityMatrix.waitDays', () {
    test('same-type uses the default interval', () {
      expect(
        EligibilityMatrix.waitDays(
          from: DonationType.wholeBlood,
          to: DonationType.wholeBlood,
        ),
        56,
      );
      expect(
        EligibilityMatrix.waitDays(
          from: DonationType.plasma,
          to: DonationType.plasma,
        ),
        28,
      );
      expect(
        EligibilityMatrix.waitDays(
          from: DonationType.platelet,
          to: DonationType.platelet,
        ),
        7,
      );
      expect(
        EligibilityMatrix.waitDays(
          from: DonationType.doubleRed,
          to: DonationType.doubleRed,
        ),
        112,
      );
    });

    test('uses the donor wait table', () {
      expect(
        EligibilityMatrix.waitDays(
          from: DonationType.wholeBlood,
          to: DonationType.plasma,
        ),
        56,
      );
      expect(
        EligibilityMatrix.waitDays(
          from: DonationType.wholeBlood,
          to: DonationType.platelet,
        ),
        7,
      );
      expect(
        EligibilityMatrix.waitDays(
          from: DonationType.wholeBlood,
          to: DonationType.doubleRed,
        ),
        56,
      );
      expect(
        EligibilityMatrix.waitDays(
          from: DonationType.plasma,
          to: DonationType.doubleRed,
        ),
        28,
      );
      expect(
        EligibilityMatrix.waitDays(
          from: DonationType.platelet,
          to: DonationType.doubleRed,
        ),
        7,
      );
      expect(
        EligibilityMatrix.waitDays(
          from: DonationType.doubleRed,
          to: DonationType.wholeBlood,
        ),
        112,
      );
      expect(
        EligibilityMatrix.waitDays(
          from: DonationType.doubleRed,
          to: DonationType.plasma,
        ),
        112,
      );
    });
  });

  group('EligibilityMatrix.evaluate', () {
    test('empty history leaves nextEligible null', () {
      final snap = EligibilityMatrix.evaluate(
        donations: const [],
        now: DateTime(2024, 6, 1),
      );
      expect(snap.hasHistory, isFalse);
      expect(snap.row(DonationType.wholeBlood).nextEligible, isNull);
    });

    test('last donation drives other types, older RBC still binds', () {
      final snap = EligibilityMatrix.evaluate(
        donations: [
          TypedDonation(
            type: DonationType.wholeBlood,
            date: DateTime(2024, 1, 1),
          ),
          TypedDonation(
            type: DonationType.doubleRed,
            date: DateTime(2024, 3, 1),
          ),
        ],
        now: DateTime(2024, 4, 1),
      );

      expect(snap.lastDonation!.type, DonationType.doubleRed);
      // Last visit is Double Red; WB is blocked 112 days from Mar 1, not 56 from Jan 1.
      expect(
        snap.row(DonationType.wholeBlood).nextEligible,
        DateTime(2024, 6, 21),
      );
      expect(
        snap.row(DonationType.wholeBlood).blockingDonation!.type,
        DonationType.doubleRed,
      );
      expect(
        snap.row(DonationType.platelet).nextEligible,
        DateTime(2024, 6, 21),
      );
    });

    test('whole blood today waits 56 for WB plasma and double red, 7 for platelets',
        () {
      final snap = EligibilityMatrix.evaluate(
        donations: [
          TypedDonation(
            type: DonationType.wholeBlood,
            date: DateTime(2024, 1, 1),
          ),
        ],
        now: DateTime(2024, 1, 1),
      );

      expect(
        snap.row(DonationType.wholeBlood).nextEligible,
        DateTime(2024, 2, 26),
      );
      expect(
        snap.row(DonationType.plasma).nextEligible,
        DateTime(2024, 2, 26),
      );
      expect(
        snap.row(DonationType.platelet).nextEligible,
        DateTime(2024, 1, 8),
      );
      expect(
        snap.row(DonationType.doubleRed).nextEligible,
        DateTime(2024, 2, 26),
      );
    });

    test('double red today waits 112 days for whole blood plasma platelets and double red',
        () {
      final snap = EligibilityMatrix.evaluate(
        donations: [
          TypedDonation(
            type: DonationType.doubleRed,
            date: DateTime(2024, 3, 1),
          ),
        ],
        now: DateTime(2024, 3, 1),
      );

      expect(
        snap.row(DonationType.wholeBlood).nextEligible,
        DateTime(2024, 6, 21),
      );
      expect(
        snap.row(DonationType.plasma).nextEligible,
        DateTime(2024, 6, 21),
      );
      expect(
        snap.row(DonationType.platelet).nextEligible,
        DateTime(2024, 6, 21),
      );
      expect(
        snap.row(DonationType.doubleRed).nextEligible,
        DateTime(2024, 6, 21),
      );
    });

    test('platelets after whole blood open sooner than another whole blood',
        () {
      final snap = EligibilityMatrix.evaluate(
        donations: [
          TypedDonation(
            type: DonationType.wholeBlood,
            date: DateTime(2024, 1, 1),
          ),
        ],
        now: DateTime(2024, 1, 10),
      );

      expect(
          snap.row(DonationType.platelet).nextEligible, DateTime(2024, 1, 8));
      expect(snap.row(DonationType.platelet).eligibleNow, isTrue);
      expect(
        snap.row(DonationType.wholeBlood).nextEligible,
        DateTime(2024, 2, 26),
      );
      expect(snap.eligibleTypesOn(DateTime(2024, 1, 10)), [
        DonationType.platelet,
      ]);
      expect(
        snap.isFirstEligibleDay(DateTime(2024, 1, 8), DonationType.platelet),
        isTrue,
      );
    });

    test('rolling yearly cap can outlast the interval wait', () {
      final donations = [
        for (var i = 0; i < 6; i++)
          TypedDonation(
            type: DonationType.wholeBlood,
            date: DateTime(2024, 1, 1).add(Duration(days: i * 56)),
          ),
      ];
      final snap = EligibilityMatrix.evaluate(
        donations: donations,
        now: DateTime(2024, 10, 20),
      );

      expect(snap.row(DonationType.wholeBlood).annualCapReached, isTrue);
      expect(
        snap.row(DonationType.wholeBlood).nextEligible,
        DateTime(2025, 1, 1),
      );
    });
  });
}
