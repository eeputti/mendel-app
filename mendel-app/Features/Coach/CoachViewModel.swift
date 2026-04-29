#if !WIDGET_EXTENSION
//
// CoachViewModel.swift
// Loads coach recommendations and manages resilient chat state.
//

import Foundation
import Combine

@MainActor
final class CoachViewModel: ObservableObject {
    // Temporary dev wiring until the authenticated Supabase user id is available in-app.
    private static let temporaryDevUserId = "0719d944-ee8e-416c-a659-31f1e54dd68a"

    @Published var coach: CoachResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var messages: [CoachMessage] = []
    @Published var draftMessage = ""
    @Published private(set) var chatState: CoachChatState = .idle

    var isSendingMessage: Bool {
        if case .sending = chatState {
            return true
        }
        return false
    }

    var canSendDraft: Bool {
        !draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSendingMessage
    }

    var isOffline: Bool {
        if case .offline = chatState {
            return true
        }
        return false
    }

    var currentFailure: CoachChatFailurePresentation? {
        switch chatState {
        case let .serverUnavailable(failure),
             let .invalidResponse(failure),
             let .authIssue(failure),
             let .offline(failure):
            return failure
        case .idle, .sending:
            return nil
        }
    }

    private let service: CoachService
    private var pendingRetry: PendingCoachRetry?

    init(service: CoachService = CoachService()) {
        self.service = service
    }

    func loadCoach(trainingContext: CoachTrainingContext) async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        do {
            coach = try await service.fetchCoachRecommendation(trainingContext: trainingContext)
        } catch {
            errorMessage = "coach is temporarily unavailable."
            debugLog(error)
        }

        isLoading = false
    }

    func updateDraft(_ value: String) {
        draftMessage = value
        switch chatState {
        case .serverUnavailable, .invalidResponse, .authIssue, .offline:
            chatState = .idle
        case .idle, .sending:
            break
        }
    }

    func sendMessage(trainingContext: CoachTrainingContext) async {
        await sendMessage(trainingContext: trainingContext, userId: Self.temporaryDevUserId)
    }

    func sendMessage(trainingContext: CoachTrainingContext, userId: String?) async {
        let trimmedMessage = draftMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty, !isSendingMessage else { return }

        let history = Array(messages.suffix(8))
        let userMessage = CoachMessage(role: .user, content: trimmedMessage, delivery: .sending)
        messages.append(userMessage)
        draftMessage = ""

        await performSend(
            messageID: userMessage.id,
            message: trimmedMessage,
            history: history,
            trainingContext: trainingContext,
            userId: userId
        )
    }

    func retryFailedMessage(trainingContext: CoachTrainingContext) async {
        guard let retry = pendingRetry, !isSendingMessage else { return }

        draftMessage = ""

        if let index = messages.firstIndex(where: { $0.id == retry.messageID }) {
            messages[index] = CoachMessage(
                id: retry.messageID,
                role: .user,
                content: retry.message,
                delivery: .sending
            )
        } else {
            messages.append(
                CoachMessage(
                    id: retry.messageID,
                    role: .user,
                    content: retry.message,
                    delivery: .sending
                )
            )
        }

        await performSend(
            messageID: retry.messageID,
            message: retry.message,
            history: retry.history,
            trainingContext: trainingContext,
            userId: retry.userId
        )
    }

    private func performSend(
        messageID: UUID,
        message: String,
        history: [CoachMessage],
        trainingContext: CoachTrainingContext,
        userId: String?
    ) async {
        chatState = .sending

        do {
            let reply = try await service.sendCoachChat(
                message: message,
                history: history,
                trainingContext: trainingContext,
                userId: userId
            )

            if let index = messages.firstIndex(where: { $0.id == messageID }) {
                messages[index] = CoachMessage(id: messageID, role: .user, content: message, delivery: .sent)
            }

            messages.append(CoachMessage(role: .assistant, content: reply))
            pendingRetry = nil
            chatState = .idle
        } catch {
            if let index = messages.firstIndex(where: { $0.id == messageID }) {
                messages[index] = CoachMessage(id: messageID, role: .user, content: message, delivery: .failed)
            }

            draftMessage = message
            pendingRetry = PendingCoachRetry(
                messageID: messageID,
                message: message,
                history: history,
                userId: userId
            )
            let mappedState = Self.presentationState(for: error)
            chatState = mappedState
            debugLog(error, mappedState: mappedState)
            return
        }
    }

    private static func presentationState(for error: Error) -> CoachChatState {
        if let coachError = error as? CoachServiceError {
            switch coachError {
            case .offline:
                return .offline(
                    CoachChatFailurePresentation(
                        title: "No connection.",
                        detail: "Check your connection or try again in a moment."
                    )
                )
            case let .backendError(_, payload, _)
                where payload?.error.code == "invalid_request" || payload?.error.code == "invalid_json":
                return .invalidResponse(
                    CoachChatFailurePresentation(
                        title: "coach had trouble replying.",
                        detail: "The request or response format was invalid. Try again in a moment."
                    )
                )
            case .timedOut(_), .backendUnavailable(_), .backendError(_, _, _):
                return .serverUnavailable(
                    CoachChatFailurePresentation(
                        title: "coach is temporarily unavailable.",
                        detail: "Check your connection or try again in a moment."
                    )
                )
            case .decodingFailed(_, _), .invalidResponse:
                return .invalidResponse(
                    CoachChatFailurePresentation(
                        title: "coach had trouble replying.",
                        detail: "The response was invalid. Try again in a moment."
                    )
                )
            case .unauthorized(_), .missingAnonKey:
                return .authIssue(
                    CoachChatFailurePresentation(
                        title: "coach needs to reconnect.",
                        detail: "Close and reopen the app, then try again."
                    )
                )
            case .invalidBaseURL, .missingBaseURL:
                return .serverUnavailable(
                    CoachChatFailurePresentation(
                        title: "coach is temporarily unavailable.",
                        detail: "Try again in a moment."
                    )
                )
            }
        }

        if let urlError = error as? URLError, urlError.code == .notConnectedToInternet {
            return .offline(
                CoachChatFailurePresentation(
                    title: "No connection.",
                    detail: "Check your connection or try again in a moment."
                )
            )
        }

        return .serverUnavailable(
            CoachChatFailurePresentation(
                title: "coach is taking a moment.",
                detail: "Check your connection or try again in a moment."
            )
        )
    }

    private func debugLog(_ error: Error, mappedState: CoachChatState? = nil) {
        #if DEBUG
        print("[CoachViewModel] Coach request surfaced to UI: \(String(describing: error))")
        if let mappedState {
            print("[CoachViewModel] Mapped UI error state: \(String(describing: mappedState))")
        }
        #endif
    }
}

private struct PendingCoachRetry {
    let messageID: UUID
    let message: String
    let history: [CoachMessage]
    let userId: String?
}
#endif
