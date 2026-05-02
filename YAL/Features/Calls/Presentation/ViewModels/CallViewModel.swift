//
//  CallViewModel.swifT.swift
//  YAL
//
//  Created by Pavithra MH on 16/09/25.
//
import Foundation
import Combine
import LiveKit
import AVFAudio
import AVFoundation
import UIKit

typealias LKRoom = LiveKit.Room

final class CallViewModel: ObservableObject {
    static let shared = CallViewModel(roomService: DIContainer.shared.container.resolve(RoomServiceProtocol.self)!, callRepository: DIContainer.shared.container.resolve(CallRepository.self)!)
    
    @Published var isConnected = false
    @Published var isMuted = false
    @Published var isCameraOn = true
    @Published var isFrontCamera = true
    @Published var callState: CallState = .end
    @Published var allParticipants: [Participant] = []
    @Published var roomModel: RoomModel?
    @Published var videoView: VideoView?                 // LiveKit VideoView used by UI
    @Published var alertModel: AlertViewModel? = nil

    var sampleBufferLayer: AVSampleBufferDisplayLayer?  // for PiP usage
    private var eventTasks = Set<Task<Void, Never>>()
    private var callRepository:CallRepository
    private var cancellables = Set<AnyCancellable>()
    private var outgoingTimer: Timer?
    private let outgoingTimeout: TimeInterval = 30
    private let roomService: RoomServiceProtocol
    
    var localVideoTrack: LocalVideoTrack?
    var lkRoomId: String?
    var eventId: String?
    var configured = false
    
    // MARK: - Initializer
    init(roomService: RoomServiceProtocol, callRepository: CallRepository) {
        self.roomService = roomService
        self.callRepository = callRepository
        setupCallKitBindings()
    }
    
    func injectParticipants(_ roomModel: RoomModel, callState: CallState) {
        DispatchQueue.main.async {
            self.roomModel = roomModel
            self.lkRoomId = roomModel.id
            self.callState = callState
        }
    }
    
    func getTokenForRoom() -> AnyPublisher<LKTokenResponse, Error> {
        var currentUserIDString: String = ""
        var currentNameString: String = ""
        var avatarUrl: String = ""
        
        if let val = Storage.get(for: .authSession, type: .keychain, as: AuthSession.self)?.userId {
            currentUserIDString = val
        }
        if let val = ContactManager.shared.contact(for: currentUserIDString) {
            
            currentNameString = val.fullName ?? ""
            
            avatarUrl = val.avatarURL ?? ""
        }
        if currentNameString.isEmpty {
            currentNameString = Storage.get(for: .mobileNumber, type: .userDefaults, as: String.self) ?? "Calling"
        }
        
        return callRepository
            .getLKAccessToken(roomName: CallManager.shared.currentRoomModel?.id ?? "", participantName: currentNameString, participantId: currentUserIDString, avatarUrl: avatarUrl)
            .tryMap { result in
                switch result {
                    case .success(let response):
                        return response
                    case .unsuccess(let apiError):
                        throw apiError
                }
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Connect
    func connect() {
        CallManager.shared.isCallActive = true
        if isConnected { return }
        
        getTokenForRoom()
            .flatMap { tokenResponse -> AnyPublisher<Void, Error> in
                // Ensure single room instance
                let lkRoom = CallSession.shared.ensureRoom()
                
                if lkRoom.connectionState == .connected || lkRoom.connectionState == .connecting {
                    return Just(()).setFailureType(to: Error.self).eraseToAnyPublisher()
                }
                
                lkRoom.add(delegate: self)
                
                return Future<Void, Error> { promise in
                    Task {
                        do {
                            try await lkRoom.connect(url: "https://livekit.yal.chat/",
                                                     token: tokenResponse.token)
                            try await lkRoom.localParticipant.setMicrophone(enabled: true)
                            try await lkRoom.localParticipant.setCamera(enabled: CallManager.shared.isVideoCall)
                            if let camTrack = lkRoom.localParticipant.videoTracks.first?.track as? LocalVideoTrack {
                                self.localVideoTrack = camTrack
                            }
                            await MainActor.run {
                                self.isConnected = true
                                self.updateParticipants()
                            }
                            // Keep the room reference in CallSession
                            self.configureAudioSession(useSpeaker: !self.isMuted)
                            
                            CallSession.shared.attachRoom(lkRoom)
                            promise(.success(()))
                        } catch {
                            promise(.failure(error))
                        }
                    }
                }
                .eraseToAnyPublisher()
            }
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    LoaderManager.shared.hide()
                    if case .failure(let error) = completion {
                        self.disconnect()
                        print("LiveKit connect failed:", error)
                    }
                },
                receiveValue: {
                    print("Connected to LiveKit room")
                }
            )
            .store(in: &cancellables)
    }
    
    private func configureAudioSession(useSpeaker: Bool = true) {
        guard !configured else { return }
        configured = true
        do {
            let session = AVAudioSession.sharedInstance()
            
            try session.setCategory(.playAndRecord,
                                    mode: .videoChat,
                                    options: [.allowBluetooth, .allowBluetoothA2DP, .duckOthers])
            
            if useSpeaker {
                try session.overrideOutputAudioPort(.speaker)
            }
            
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            print("AudioSession configured (speaker: \(useSpeaker))")
            
        } catch {
            print("AudioSession error:", error.localizedDescription)
        }
    }
    
    // MARK: - Disconnect
    func disconnect() {
        print("LivekitLog --- disconnect called ")
        Task {
            try? AVAudioSession.sharedInstance().setActive(false)
            CallKitManager.shared.endCall()
            
            DispatchQueue.main.async {
                CallManager.shared.callState = .end
                CallManager.shared.updateCallStatus()
                CallManager.shared.endCall()
                self.allParticipants.removeAll()
                self.eventTasks.forEach { $0.cancel() }
                self.eventTasks.removeAll()
                self.isConnected = false
            }
            await CallSession.shared.disconnectAndClear()
        }
        
    }

    // MARK: - Toggle mic / camera
    func toggleMute() {
        guard let local = CallSession.shared.room?.localParticipant else { return }
        Task {
            await MainActor.run {
                isMuted.toggle()
            }
            try await local.setMicrophone(enabled: !isMuted)
            //CallKitManager.shared.setMuted(isMuted, uuid: UUID()) // todo - This is to set callkit state
        }
    }
    
    func toggleCamera() {
        guard let local = CallSession.shared.room?.localParticipant else { return }
        Task {
            await MainActor.run {
                isCameraOn.toggle()
            }
            try await local.setCamera(enabled: isCameraOn)
            await self.updateParticipants()
        }
    }
    
    func toggleCameraFrontBack() async {
        guard let capture = localVideoTrack?.capturer as? CameraCapturer else {
            print(" No camera capturer found for switching")
            return
        }
        do {
            try await capture.switchCameraPosition()
        }catch{
            
        }
        Task {
            await MainActor.run {
                isFrontCamera.toggle()
            }
        }
    }
    
    func toggleSpeaker() {
        CallManager.shared.isSpeakerOn.toggle()
        
        do {
            let session = AVAudioSession.sharedInstance()
            
            if CallManager.shared.isSpeakerOn {
                try session.overrideOutputAudioPort(.speaker)
            } else {
                try session.overrideOutputAudioPort(.none)
            }
            
            try session.setActive(CallManager.shared.isSpeakerOn)
            print("Speaker changed: \(CallManager.shared.isSpeakerOn)")
            
        } catch {
            print("Speaker toggle error:", error)
        }
    }
    
    func acceptCall() {
        self.connect()
        CallManager.shared.updateCallStatus()
    }
    
    func declineCall() {
        disconnect()
        CallManager.shared.updateCallStatus()
        CallKitManager.shared.endCall()
    }
    
    @MainActor
    private func updateParticipants() {
        // Keep the room reference in CallSession
        guard let room = CallSession.shared.room else { return }
        
        // Attach delegates (safe to reattach)
        //        room.localParticipant.add(delegate: self)
        for remote in room.remoteParticipants.values {
            remote.add(delegate: self)
        }
        
        // Update your list
        var all = [Participant]()
        all.append(room.localParticipant)
        all.append(contentsOf: Array(room.remoteParticipants.values))
        allParticipants = all
        print(" localParticipant isCameraEnabled :", room.localParticipant.isCameraEnabled())
        
        print(" Total participants:", allParticipants.count)
    }
    
    /// Called by the SwiftUI wrapper when the VideoView is created/updated.
    /// Attaches local video track and remote subscriptions if applicable.
    /// Also captures the AVSampleBufferDisplayLayer so PiP can be configured.
    func register(videoView: VideoView) {
//        DispatchQueue.main.async { [weak self] in
//            guard let self = self else { return }
//            
//            // avoid re-registering the same view repeatedly
//            if let existing = self.videoView, existing === videoView {
//                // ensure sample buffer layer set (might be present now)
//                if self.sampleBufferLayer == nil, let layer = videoView.avSampleBufferDisplayLayer {
//                    self.sampleBufferLayer = layer
//                    PiPManager.shared.setup(layer: layer)
//                }
//                return
//            }
//            
//            self.videoView = videoView
//            
//            // Attach the local track (if available)
//            if let localTrack = self.localVideoTrack {
//                localTrack.add(videoRenderer: videoView)
//            } else {
//                // try to attach the first video track from the room (if published)
//                if let room = CallSession.shared.room,
//                   let localTrack = room.localParticipant.videoTracks.first?.track as? LocalVideoTrack {
//                    self.localVideoTrack = localTrack
//                    localTrack.add(videoRenderer: videoView)
//                }
//            }
//            
//            // Also attach remote participants' first video track (optional)
//            if let room = CallSession.shared.room {
//                for remote in room.remoteParticipants.values {
//                    if let pub = remote.videoTracks.first,
//                       let track = pub.track {
//                        videoView.track = track as? VideoTrack
//                    }
//                }
//            }
//            
//            // capture AVSampleBufferDisplayLayer for PiP
//            if let layer = videoView.avSampleBufferDisplayLayer {
//                self.sampleBufferLayer = layer
//                PiPManager.shared.setup(layer: layer)
//            }
//        }
    }
}


// MARK: - RoomDelegate
extension CallViewModel : RoomDelegate {
    
    func roomDidConnect(_ room: LiveKit.Room) {
        print("LivekitLog --- roomDidConnect -- \(String(describing: self.lkRoomId))--  \(room.allParticipants.count)")
        CallKitManager.shared.reportCallConnected()
        startOutgoingTimeout()
        Task { [weak self] in
            if(room.allParticipants.count >= 1){
                DispatchQueue.main.async {
                    CallManager.shared.callState = .ongoing
                }
            }
            await self?.updateParticipants()
        }
    }
    
    func room(_ room: LiveKit.Room, participantDidConnect participant: RemoteParticipant) {
        cancelOutgoingTimeout()
        CallManager.shared.stopRingbackTone()
        participant.add(delegate: self)
        Task {
            await updateParticipants()
            DispatchQueue.main.async {
                CallManager.shared.callState = .ongoing
            }
        }
    }
    
    func room(_ room: LiveKit.Room, participantDidDisconnect participant: RemoteParticipant) {
        if room.allParticipants.count == 1 {
            self.disconnect()
        }
        Task { await updateParticipants() }
    }
    
    func room(_ room: LiveKit.Room, participant: Participant, didUpdateState state: ParticipantState) {
        Task { await updateParticipants() }
    }
    
    func room(_ room: LiveKit.Room, connectionStateDidChange state: ConnectionState, from oldState: ConnectionState) {
        if state == .disconnected {
            cancelOutgoingTimeout()
            isConnected = false
            allParticipants.removeAll()
            self.disconnect()
        }
    }
    
    private func startOutgoingTimeout() {
        cancelOutgoingTimeout() // avoid duplicates
        
        outgoingTimer = Timer.scheduledTimer(withTimeInterval: outgoingTimeout, repeats: false) { [weak self] _ in
            self?.handleOutgoingTimeout()
        }
    }
    
    private func cancelOutgoingTimeout() {
        outgoingTimer?.invalidate()
        outgoingTimer = nil
    }
    
    private func handleOutgoingTimeout() {
        guard callState == .outgoing else { return }
        
        CallManager.shared.callState = .end
        self.disconnect()
        
        // notify UI or store missed event if needed
        NotificationCenter.default.post(name: .callStateChanged, object: CallState.end)
    }
    
    func attachLocalIfNeeded(_ participant: Participant) {
        if participant is LocalParticipant {
            guard let videoTrack = participant.videoTracks.first?.track as? LocalVideoTrack else { return }
            
            // Already attached → do nothing
            if self.localVideoTrack === videoTrack {
                return
            }
            self.localVideoTrack = videoTrack
            
            if let view = videoView {
                videoTrack.add(videoRenderer: view)
            }
        }
    }
    
    func detachLocalIfNeeded(_ participant: Participant) {
        if participant is LocalParticipant {
            
            guard let view = videoView else { return }
            
            self.localVideoTrack?.remove(videoRenderer: view)
        }
    }
    
}

// MARK: - ParticipantDelegate
extension CallViewModel: ParticipantDelegate {
    func participant(_ participant: Participant, didUpdateIsSpeaking speaking: Bool) {
        print(" \(String(describing: participant.identity)) speaking: \(speaking)")
    }
    
    func participant(_ participant: Participant, trackPublication: TrackPublication, didUpdateIsMuted isMuted: Bool) {
        Task {
            await self.updateParticipants()
        }
    }
    
//    // MARK: - Track Published
//    
//    func participant(_ participant: Participant, didPublishTrack publication: TrackPublication) {
//        attachLocalIfNeeded(participant)
//    }
//    
//    func participant(_ participant: Participant, didUnpublishTrack publication: TrackPublication) {
//        detachLocalIfNeeded(participant)
//    }
//    
//    // MARK: - Track Subscribed
//    func participant(_ participant: Participant, didSubscribeTrack publication: TrackPublication, track: Track) {
//            
//        if let videoTrack = track as? VideoTrack {
//            print("Subscribed VIDEO:", videoTrack.sid)
//        }
//        
//        attachLocalIfNeeded(participant)
//    }
//    
//    func participant(_ participant: Participant, didUnsubscribeTrack publication: TrackPublication, track: Track) {
//        detachLocalIfNeeded(participant)
//    }
    
    // MARK: - Speaking
    func participant(_ participant: Participant, didUpdateSpeaking speaking: Bool) {
        
        print("Speaking:", speaking)
    }
    
    // MARK: - Track Updated
    func participant(_ participant: Participant, didUpdate track: TrackPublication) {
        
        print("Track updated:", track.id)
    }
    
}


// MARK: - Notification Extension
extension Notification.Name {
    static let callStateChanged = Notification.Name("callStateChanged")
    static let callKitAccepted = Notification.Name("callKitAccepted")
    static let callKitEnded = Notification.Name("callKitEnded")
}

extension CallViewModel {
    func setupCallKitBindings() {
        NotificationCenter.default.publisher(for: .callKitAccepted)
            .sink { [weak self] notification in
                if let (roomId, isVideo, eventId) = notification.object as? (String, Bool, String) {
                    self?.lkRoomId = roomId
                    self?.eventId = eventId
                    CallManager.shared.updateCallStatus()
                    self?.connect()
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .callKitEnded)
            .sink { [weak self] _ in
                CallManager.shared.callState = .decline
                CallManager.shared.updateCallStatus()
                self?.disconnect()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(
            for: UIApplication.didEnterBackgroundNotification
        )
        .sink { _ in
            if CallManager.shared.isVideoCall &&
                CallManager.shared.callState == .ongoing {
                PiPManager.shared.start()
            }
        }
        .store(in: &cancellables)
        
        NotificationCenter.default.publisher(
            for: UIApplication.willEnterForegroundNotification
        )
        .sink { _ in
            PiPManager.shared.stop()
        }
        .store(in: &cancellables)
    }
}
