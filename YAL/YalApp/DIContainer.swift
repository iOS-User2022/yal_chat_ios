//
//  DIContainer.swift
//  YAL
//
//  Created by Vishal Bhadade on 10/04/25.
//


import Swinject

final class DIContainer {
    static let shared = DIContainer()
    let container = Container()

    private init() {
        registerCore()
        registerRepositories()
        registerViewModels()
    }

    // MARK: - Core Services (Router, SDKs, DB)

    private func registerCore() {
        container.register(Router.self) { _ in Router() }
            .inObjectScope(.container)

        container.register(MatrixAPIManagerProtocol.self) { r in
            let matrixManager = MatrixAPIManager.shared
            let httpClient = r.resolve(HttpClient.self)!
            matrixManager.injectHTTPClient(httpClient: httpClient)
            return matrixManager
        }
        .inObjectScope(.container)

        container.register(AuthSessionProvider.self) { _ in
            KeychainAuthSessionProvider()
        }.inObjectScope(.container)

        // Register TokenProvider
        container.register(TokenProvider.self) { r in
            return TokenProviderAdapter(sessionProvider: r.resolve(AuthSessionProvider.self)!)
        }.inObjectScope(.container)

        // Register HttpClient
        container.register(HttpClient.self) { r in
            HttpClient(tokenProvider: r.resolve(TokenProvider.self)!)
        }.inObjectScope(.transient)
        
        container.register(DBManageable.self) { _ in
            DBManager.shared // Accessing the shared instance of DataManager
        }  // This will keep the instance alive throughout the container's lifecycle
        
        container.register(EnvironmentManager.self) { _ in EnvironmentManager() }.inObjectScope(.container)

        container.register(ApiManageable.self) { r in
            ApiManager(httpClient: r.resolve(HttpClient.self)!, env: r.resolve(EnvironmentManager.self)!)
        }.inObjectScope(.container)
        
        container.register(ContactSyncCoordinator.self) { r in
            ContactSyncCoordinator(userRepository: r.resolve(UserRepository.self)!)
        }.inObjectScope(.container)
        
        container.register(APNsTokenStore.self) { r in
            APNsTokenStore()
        }.inObjectScope(.container)
        
        container.register(PushRegistrationCoordinator.self) { r in
            PushRegistrationCoordinator(
                registerUC: r.resolve(RegisterPusherUseCase.self)!,
                unregisterUC: r.resolve(UnregisterPusherUseCase.self)!,
                apnsStore: r.resolve(APNsTokenStore.self)!,
                tokenProvider: r.resolve(TokenProvider.self)!,
            )
        }.inObjectScope(.container)
    }

    // MARK: - Repositories

    private func registerRepositories() {
        container.register(AuthRepository.self) { r in
            AuthRepository(apiManager: r.resolve(ApiManageable.self)!)
        }.inObjectScope(.container)

        container.register(ChatRepository.self) { r in
            ChatRepository(
                matrixAPIManager: r.resolve(MatrixAPIManagerProtocol.self)!,
                userRepository: r.resolve(UserRepository.self)!
            )
        }.inObjectScope(.container)
        
        container.register(UserRepository.self) { r in
            UserRepository(apiManager: r.resolve(ApiManageable.self)!)
        }
        
        container.register(PushRegistrationRepositoryProtocol.self) { r in
            PushRegistrationRepository(
                matrixAPIManager: r.resolve(MatrixAPIManagerProtocol.self)!,
                tokenProvider: r.resolve(TokenProvider.self)!
            )
        }
        // Add ChatRepository, SettingsRepository, etc. here later
    }

    // MARK: - ViewModels

    private func registerViewModels() {
        // Auth
        container.register(AuthViewModel.self) { r in
            AuthViewModel(
                router: r.resolve(Router.self)!
            )
        }

        container.register(LoginViewModel.self) { r in
            LoginViewModel(authRepository: r.resolve(AuthRepository.self)!)
        }

        container.register(OtpViewModel.self) { r, phone in
            OtpViewModel(
                phone: phone,
                authRepository: r.resolve(AuthRepository.self)!
            )
        }

        container.register(GetStartedViewModel.self) { r in
            GetStartedViewModel(userRepository: r.resolve(UserRepository.self)!, authViewModel: r.resolve(AuthViewModel.self)!)
        }
        
        container.register(LoadingViewModel.self) { r in
            LoadingViewModel(repo: r.resolve(ChatRepository.self)!)
        }
        
        container.register(TabBarViewModel.self) { r in
            TabBarViewModel(
                router: (r.resolve(Router.self)!),
                userRepository: r.resolve(UserRepository.self)!,
                contactSyncCoordinator: r.resolve(ContactSyncCoordinator.self)!
            )
        }
        
        container.register(ProfileMenuViewModel.self) { r in
            ProfileMenuViewModel(userRepository: r.resolve(UserRepository.self)!)
        }
        
        // Profile
        container.register(ProfileViewModel.self) { r in
            ProfileViewModel(
                userRepository: r.resolve(UserRepository.self)!,
                router: r.resolve(Router.self)!
            )
        }

        container.register(SettingsViewModel.self) { r in
            SettingsViewModel(
                dbManager: r.resolve(DBManageable.self)!,
                apiManager: r.resolve(ApiManageable.self)!,
                router: r.resolve(Router.self)!
            )
        }
        
        container.register(NotificationPreferencesViewModel.self) { _ in
            return NotificationPreferencesViewModel()
        }.inObjectScope(.transient)
        
        container.register(ChatViewModel.self) { r in
            ChatViewModel(roomService: r.resolve(RoomServiceProtocol.self)!)
        }.inObjectScope(.container)
        
        container.register(RoomServiceProtocol.self) { resolver in
            RoomService(
                chatRepository: resolver.resolve(ChatRepository.self)!,
                userRepository: resolver.resolve(UserRepository.self)!
            )
        }.inObjectScope(.container)
        
        container.register(RoomListViewModel.self) { r in
            RoomListViewModel(roomService: r.resolve(RoomServiceProtocol.self)!)
        }
        
        container.register(ContactListViewModel.self) { r in
            ContactListViewModel(contactSyncCoordinator: r.resolve(ContactSyncCoordinator.self)!)
        }
        
        container.register(SelectContactListViewModel.self) { r in
            SelectContactListViewModel(
                apiManager: r.resolve(ApiManageable.self)!,
                contactSyncCoordinator: r.resolve(ContactSyncCoordinator.self)!
            )
        }
        
        container.register(UserProfileViewModel.self) { r, user, room in
            let roomService = r.resolve(RoomServiceProtocol.self)!
            return UserProfileViewModel(user: user, currentRoom: room, roomService: roomService)
        }
        
        container.register(ForwardMessageViewModel.self) { resolver in
            ForwardMessageViewModel(
                roomService: resolver.resolve(RoomServiceProtocol.self)!,
                contactSyncCoordinator: resolver.resolve(ContactSyncCoordinator.self)!
            )
        }
        
        container.register(RoomDetailsViewModel.self) { resolver, room in
            RoomDetailsViewModel(roomService: resolver.resolve(RoomServiceProtocol.self)!, room: room)
        }
        
        container.register(MatrixPusherService.self) { r in
            MatrixPusherService(
                matrixPusherRepository: r.resolve(PushRegistrationRepositoryProtocol.self)!
            )
        }
        
        container.register(RegisterPusherUseCase.self) { r in
            RegisterPusherUseCase(service: r.resolve(MatrixPusherService.self)!)
        }
        
        container.register(UnregisterPusherUseCase.self) { r in
            UnregisterPusherUseCase(service: r.resolve(MatrixPusherService.self)!)
        }
    }
}


