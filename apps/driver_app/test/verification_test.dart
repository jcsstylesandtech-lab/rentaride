import 'package:flutter_test/flutter_test.dart';
import 'package:rent_a_ride_driver/data/models.dart';
import 'package:rent_a_ride_driver/state/providers.dart';

DriverDocument doc(DocumentType t, {String review = 'pending'}) => DriverDocument(
    id: t.db, type: t, review: review, note: null, createdAt: DateTime(2026, 11, 27));

void main() {
  test('proof of address is a required document read from the database', () {
    expect(DocumentType.fromDb('proof_of_address'), DocumentType.proofOfAddress);
    expect(DocumentType.proofOfAddress.required, isTrue);
  });

  test('the face photo tells drivers it becomes their profile picture', () {
    expect(DocumentType.profilePhoto.hint, contains('profile picture'));
  });

  test('documents are incomplete until proof of address is uploaded', () {
    final required = DocumentType.values.where((t) => t.required);
    final without = [for (final t in required) if (t != DocumentType.proofOfAddress) doc(t)];
    DriverState state(List<DriverDocument> d) =>
        DriverState(profile: null, driver: null, vehicles: const [], documents: d);
    expect(state(without).docsComplete, isFalse);
    expect(state([...without, doc(DocumentType.proofOfAddress)]).docsComplete, isTrue);
    expect(state([...without, doc(DocumentType.proofOfAddress, review: 'rejected')]).docsComplete, isFalse);
  });

  test('home address is read from the drivers row', () {
    final d = Driver.fromJson({'id': 'x', 'status': 'pending', 'home_address': '12 Adeola Odeku St, Lagos'});
    expect(d.homeAddress, '12 Adeola Odeku St, Lagos');
  });
}
