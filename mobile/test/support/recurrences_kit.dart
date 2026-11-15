import 'package:mobile/features/recurrences/domain/usecases/create_recurrence.dart';
import 'package:mobile/features/recurrences/domain/usecases/delete_recurrence.dart';
import 'package:mobile/features/recurrences/domain/usecases/list_recurrences.dart';
import 'package:mobile/features/recurrences/domain/usecases/provision_next_month.dart';
import 'package:mobile/features/recurrences/domain/usecases/update_recurrence.dart';
import 'package:mobile/features/recurrences/presentation/viewmodels/recurrences_view_model.dart';

import 'fake_recurrences_repository.dart';

/// The recurrences ViewModel over a fake repository. "Today" is 13 November
/// 2026, so the next month is December.
class RecurrencesKit {
  RecurrencesKit({DateTime? now}) : repository = FakeRecurrencesRepository() {
    viewModel = RecurrencesViewModel(
      listRecurrences: ListRecurrences(repository),
      createRecurrence: CreateRecurrence(repository),
      updateRecurrence: UpdateRecurrence(repository),
      deleteRecurrence: DeleteRecurrence(repository),
      provisionNextMonth: ProvisionNextMonth(repository),
      now: () => now ?? DateTime(2026, 11, 13, 9),
    );
  }

  final FakeRecurrencesRepository repository;
  late final RecurrencesViewModel viewModel;
}
