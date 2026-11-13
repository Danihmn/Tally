import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/failure.dart';
import 'package:mobile/core/widgets/offline_banner.dart';

import '../../support/pump_app.dart';

void main() {
  group('OfflineBanner', () {
    testWidgets('shows_only_for_a_network_failure', (tester) async {
      await pumpApp(tester, const OfflineBanner(failure: NetworkFailure()));
      expect(find.textContaining('sem conexão'), findsOneWidget);

      await pumpApp(tester, const OfflineBanner(failure: TimeoutFailure()));
      expect(find.textContaining('sem conexão'), findsNothing);

      await pumpApp(tester, const OfflineBanner(failure: null));
      expect(find.textContaining('sem conexão'), findsNothing);
    });
  });
}
