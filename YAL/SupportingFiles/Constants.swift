//
//  File.swift
//  YAL
//
//  Created by Hari krishna on 05/03/26.
//

import Foundation

enum Constants: String {
    case inviteFriends = "INVITE_FRIENDS"
    case contactOnYal = "CONTACT_ON_YAL"
    case editProfileTitle = "EDIT_PROFILE_TITLE"
    case editProfileInputPlaceholder = "EDIT_PROFILE_INPUT_PLACEHOLDER"
    case editProfileGenderPlaceholder = "EDIT_PROFILE_GENDER_PLACEHOLDER"
    case editProfileDatePlaceholder = "EDIT_PROFILE_DATE_PLACEHOLDER"
    case editProfileDoneButton = "EDIT_PROFILE_DONE_BUTTON"
    case editProfileCancelButton = "EDIT_PROFILE_CANCEL_BUTTON"
    case editProfileSaveButton = "EDIT_PROFILE_SAVE_BUTTON"
    case about = "ABOUT"
    case name = "NAME"
    case gender = "GENDER"
    case email = "EMAIL"
    case dateOfBirth = "D.O.B."
    case profession = "PROFESSION"
    case ContactInfo = "CONTACT_INFO"
    case DeleteContact = "DELETE_CONTACT"
    
    case chat =  "Chat"
    case call =  "Call"
    case video = "Video"
    case addToFavorites = "Add to favorites"
    case reportSpam  = "Report a spam"
    case block = "Block"
    case searchPlaceholderText = "Search numbers, names & more"
    case contactPermissionDenied = "Contacts permission denied."
    case contactAccessRestricted = "Contacts access is restricted."
    
    case male = "Male"
    case female = "Female"
    case other = "Other"
    case selectGender = "Select Gender"
    case mobile = "Mobile"
    case dob = "D. O. B."
    case profession1 = "Profession"
    case editProfile = "Edit Profile"
    case profile = "Profile"
    case notSet = "Not set"
    case editAbout = "Edit About"
    case cancel = "Cancel"
    case save = "Save"
    case chatClearedTitle = "CHAT_CLEARED_TITLE"
    case chatClearedMessage = "CHAT_CLEARED_MESSAGE"
    case okButton = "OK_BUTTON"
        
    case lockThisChat = "LOCK_THIS_CHAT"
    case lockedChatsDesc = "LOCKED_CHATS_DESC"
    case lock = "LOCK"
    case cancelUpper = "CANCEL"

    case secureYourChats = "SECURE_YOUR_CHATS"
    case protectChatsDesc = "PROTECT_CHATS_DESC"
    case useBiometrics = "USE_BIOMETRICS"
    case setPin = "SET_PIN"

    case chatsProtectedTitle = "CHATS_PROTECTED_TITLE"
    case chatsProtectedDesc = "CHATS_PROTECTED_DESC"
    case continueAction = "CONTINUE"

    case lockedChatsTitle = "LOCKED_CHATS_TITLE"
    case remove = "REMOVE"

    case manageLockedChats = "MANAGE_LOCKED_CHATS"
    case enableLockedChats = "ENABLE_LOCKED_CHATS"
    case lockChatSecurity = "LOCK_CHAT_SECURITY"
    case setPinAction = "SET_PIN_ACTION"

    case biometricSystemDefault = "BIOMETRIC_SYSTEM_DEFAULT"
    case faceIdSystemDefault = "FACEID_SYSTEM_DEFAULT"
    case pin = "PIN"

    case verifyPin = "VERIFY_PIN"
    case setPinTitle = "SET_PIN_TITLE"

    case setPinDesc = "SET_PIN_DESC"
    case verifyPinDesc = "VERIFY_PIN_DESC"

    case verify = "VERIFY"
    case saveUpper = "SAVE"

    case lockedChats = "LOCKED_CHATS"
    case authenticateSecureChats = "AUTHENTICATE_SECURE_CHATS"
    case downloadingMessages = "DOWNLOADING_MESSAGES"

    case incorrectPin = "INCORRECT_PIN"
    case ok = "OK"

    case inboxEmpty = "INBOX_EMPTY"
    case startNewChat = "START_NEW_CHAT"
    case messageContact = "MESSAGE_CONTACT"

    case inviteFriend = "INVITE_FRIEND"
    case discoverContactsYal = "DISCOVER_CONTACTS_YAL"
    case chooseContact = "CHOOSE_CONTACT"

    case connectFriendsYal = "CONNECT_FRIENDS_YAL"
    case inviteShareText = "INVITE_SHARE_TEXT"

    case searchPlaceholder = "SEARCH_PLACEHOLDER"
    case voice = "VOICE"
    case authTxt = "Authenticate to secure your chats"
    case blockedByAdmin = "BLOCKED_BY_ADMIN"
    
    case copiedToclipBoard = "Copied to Clipboard"
    case chatVideo = "video"
    case chatVoice = "voice"
    case ronaldhasnotMsged = "Ronald hasn’t messaged you yet."
    case chatStartTheConversation = "Start the conversation or tap on the messages below."
    case chatNoResultsFound = "No results found"
    case selected = "Selected"
    case forward = "Forward"
    case cantSendAnyMessage = "You can't send any messages,"
    case youAreNoLongerMember = "you are no longer a member."
    case userDeletedTheMessage = "User deleted the message"
    case chatPdf = "pdf"
    case chatDoc = "docx"
    case chatXlsx = "xlsx"
    case chatPptx  = "pptx"
    case chatJson = "json"
    case chatCsv = "csv"
    case chatAudioM4a = "audio.m4a"
    case chatAuidom4a = "audio/m4a"
    case chatMembers = "Members"
    case chatYouCantreactMessages = "You can't react to messages,"
    case chatDismiss = "Dismiss"
    case mVoiceCall = "m.voiceCall"
    case mVideoCall = "m.videoCall"
    case chatDeleteForEveryOne =  "Delete for everyone"
    case chatDeleteForMe = "Delete for me"
    case search = "Search"
    case unBlockUser = "Unblock User"
    case chatCamera = "Camera"
    case chatGallery =  "Gallery"
    case chatDocument =  "Document"
    case chatAuio =  "Audio"
    case howareyouRonald = "How are you, Ronald?"
    case howItsGoing = "How’s it going?"
    case heyRonald = "Hey Ronald!"
    case uCreatedThisGroup = "You created this group"
    case chatGroup = "Group ·"
    case chatMember = "member"
    case startChat = "Start chat"
    case addMembers = "Add members"
    case isTyping = " is Typing"
    case areTyping = "are typing"
    case and = "and"
    case othersTyping = "others are typing"
    case user = "user"
    case message = "Message"
    
    // MARK: - Blocked Users Screen
    case blockedUser = "Blocked User"
    case noBlockedRooms = "No blocked rooms"
    case removeButton = "Remove"
    
    case shareItemStr = "Hey! Join me on YAL. Download the app here: https://yourapplink.com"
    case callLogEmpty = "Your call log is empty."
    case startNewCall = "Start a new call!"
    case callContact = "Call a Contact"
    case inviteFriendCallLogView = "Invite a friend"
    case deviceNotSupportPhoneCall = " This device does not support phone calls."
    case tell = "tel://"
    case today = "Today"
    case yesterday = "Yesterday"
    case searchNamesAndMore = "Search names & more"
    case phoneNumberCount = "phoneNumbers.@count > 0"
    case callAddImage = "call-add"
    case group34Image = "Group 34"
    case ellipseImage = "Ellipse 137"
    
    case selectContact = "Select Contact"
    case yalContact = "Yal contacts"
    case crossBlack = "cross-black"
    case contactOnYalAi = "Contact on YAL.ai"
    case inviteOnYalAi = "Invite on YAL.ai"
    case inviteTapped = "Invite tapped for"
    case newGroup = "new-group"
    case newGroup1 = "New Group"
    case newContact = "new-contact"
    case newContact1 = "New Contact"
    case invite = "Invite"
    
}

extension Constants {
    var localized: String {
        NSLocalizedString(self.rawValue, comment: "")
    }
}

