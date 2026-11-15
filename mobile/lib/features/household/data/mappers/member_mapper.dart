import 'package:mobile/features/household/data/models/member_dto.dart';
import 'package:mobile/features/household/domain/entities/member.dart';

extension MemberDtoMapper on MemberDto {
  Member toEntity() => Member(
    id: id,
    firstName: firstName,
    householdId: householdId,
    lastName: lastName,
    surname: surname,
    email: email,
  );
}
