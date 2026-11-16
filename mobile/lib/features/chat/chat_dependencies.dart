import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:mobile/features/chat/data/datasources/chat_remote_data_source.dart';
import 'package:mobile/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:mobile/features/chat/domain/repositories/chat_repository.dart';
import 'package:mobile/features/chat/domain/usecases/get_conversation.dart';
import 'package:mobile/features/chat/domain/usecases/get_conversations.dart';
import 'package:mobile/features/chat/domain/usecases/send_chat_message.dart';
import 'package:mobile/features/chat/presentation/viewmodels/chat_view_model.dart';
import 'package:mobile/features/chat/presentation/viewmodels/conversations_view_model.dart';

/// Registers the Tally AI chat feature.
void registerChatDependencies(GetIt container) {
  container
    ..registerLazySingleton<ChatRemoteDataSource>(
      () => ChatRemoteDataSource(container<Dio>()),
    )
    ..registerLazySingleton<ChatRepository>(
      () => ChatRepositoryImpl(container<ChatRemoteDataSource>()),
    )
    ..registerLazySingleton<SendChatMessage>(
      () => SendChatMessage(container<ChatRepository>()),
    )
    ..registerLazySingleton<GetConversations>(
      () => GetConversations(container<ChatRepository>()),
    )
    ..registerLazySingleton<GetConversation>(
      () => GetConversation(container<ChatRepository>()),
    )
    ..registerFactory<ChatViewModel>(
      () => ChatViewModel(
        sendMessage: container<SendChatMessage>(),
        getConversation: container<GetConversation>(),
      ),
    )
    ..registerFactory<ConversationsViewModel>(
      () => ConversationsViewModel(
        getConversations: container<GetConversations>(),
      ),
    );
}
