import SwiftUI
import UIKit

/// A follow-up help chat presented as a sheet (so the keyboard lifts the input and
/// dismissing returns to the info page, not home). Type a comment and/or attach a
/// photo and get a reply.
struct ChatView: View {
    @ObservedObject var vm: ChatViewModel
    @EnvironmentObject private var lang: LanguageManager
    @Environment(\.dismiss) private var dismiss

    @State private var input: String = ""
    @State private var attached: UIImage?
    @State private var activePicker: PhotoSource?
    @FocusState private var inputFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(vm.messages) { message in
                            bubble(message).id(message.id)
                        }
                        if vm.isSending {
                            HStack(spacing: 6) {
                                ProgressView().tint(Theme.leafDeep)
                                Text(lang.t("Thinking…", "Думаю…"))
                                    .font(.footnote).foregroundStyle(Theme.subtleInk)
                            }
                            .id("typing")
                        }
                        if let error = vm.errorText {
                            Text(error).font(.footnote).foregroundStyle(.red)
                        }
                    }
                    .padding(16)
                }
                .scrollDismissesKeyboard(.immediately)
                .onTapGesture { inputFocused = false }
                .onChange(of: vm.messages.count) { _ in
                    withAnimation { proxy.scrollTo(vm.messages.last?.id, anchor: .bottom) }
                }
                .onChange(of: vm.isSending) { sending in
                    if sending { withAnimation { proxy.scrollTo("typing", anchor: .bottom) } }
                }
            }
            .background(Color(.systemGroupedBackground))
            .safeAreaInset(edge: .bottom) { inputBar }
            .navigationTitle(lang.t("Clarify", "Уточнити"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Label(lang.t("Back", "Назад"), systemImage: "chevron.left")
                    }
                    .tint(Theme.leafDeep)
                }
                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button(lang.t("Done", "Готово")) { inputFocused = false }
                            .tint(Theme.leafDeep)
                    }
                }
            }
            .fullScreenCover(item: $activePicker) { source in
                picker(for: source).ignoresSafeArea()
            }
        }
    }

    private func bubble(_ message: ChatMessage) -> some View {
        let isUser = message.role == .user
        return HStack {
            if isUser { Spacer(minLength: 40) }
            VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
                if let image = message.image {
                    Image(uiImage: image)
                        .resizable().scaledToFill()
                        .frame(width: 150, height: 110)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                if !message.text.isEmpty {
                    Text(message.text)
                        .font(.subheadline)
                        .foregroundStyle(isUser ? .white : Theme.ink)
                        .padding(.horizontal, 12).padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(isUser ? AnyShapeStyle(Theme.leafDeep)
                                             : AnyShapeStyle(Color(.secondarySystemGroupedBackground)))
                        )
                }
            }
            if !isUser { Spacer(minLength: 40) }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }

    private var inputBar: some View {
        VStack(spacing: 8) {
            if let attached {
                HStack(spacing: 8) {
                    Image(uiImage: attached)
                        .resizable().scaledToFill()
                        .frame(width: 46, height: 46)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    Text(lang.t("Photo attached", "Фото додано"))
                        .font(.footnote).foregroundStyle(Theme.subtleInk)
                    Spacer()
                    Button { self.attached = nil } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.subtleInk.opacity(0.6))
                    }
                }
            }
            HStack(spacing: 10) {
                Menu {
                    Button { activePicker = .library } label: {
                        Label(lang.t("Choose from library", "Обрати з галереї"), systemImage: "photo")
                    }
                    if CameraAuthorization.isCameraAvailable {
                        Button { startCamera() } label: {
                            Label(lang.t("Take a photo", "Зробити фото"), systemImage: "camera")
                        }
                    }
                } label: {
                    Image(systemName: "paperclip").font(.title3).foregroundStyle(Theme.leafDeep)
                }

                TextField(lang.t("Type a comment…", "Напишіть коментар…"), text: $input, axis: .vertical)
                    .lineLimit(1...4)
                    .focused($inputFocused)
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .background(RoundedRectangle(cornerRadius: 18).fill(Color(.tertiarySystemFill)))

                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title)
                        .foregroundStyle(canSend ? Theme.leafDeep : Theme.subtleInk.opacity(0.4))
                }
                .disabled(!canSend)
            }
        }
        .padding(12)
        .background(.bar)
    }

    private var canSend: Bool {
        !vm.isSending && (!input.trimmingCharacters(in: .whitespaces).isEmpty || attached != nil)
    }

    private func sendMessage() {
        vm.send(text: input, image: attached)
        input = ""
        attached = nil
        inputFocused = false
    }

    private func startCamera() {
        guard CameraAuthorization.isCameraAvailable else { return }
        Task { if await CameraAuthorization.requestAccess() { activePicker = .camera } }
    }

    @ViewBuilder
    private func picker(for source: PhotoSource) -> some View {
        let onImage: (UIImage) -> Void = { image in attached = image; activePicker = nil }
        switch source {
        case .camera: CameraPicker(onImage: onImage, onCancel: { activePicker = nil })
        case .library: LibraryPicker(onImage: onImage, onCancel: { activePicker = nil })
        }
    }
}
