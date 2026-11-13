import 'package:equatable/equatable.dart';

/// A range of days, both ends included. Only the date counts, not the time.
class DateRange extends Equatable {
  const DateRange({required this.from, required this.to});

  final DateTime from;
  final DateTime to;

  @override
  List<Object?> get props => [from, to];
}
