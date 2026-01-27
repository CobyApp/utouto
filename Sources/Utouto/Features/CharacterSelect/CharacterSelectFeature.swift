import SwiftUI
import ComposableArchitecture

@Reducer
struct CharacterSelectFeature {
    @ObservableState
    struct State: Equatable {
        var characters: [Character] = []
        var selectedCharacterId: String?
        var isPlayingPreview = false
    }

    enum Action {
        case loadCharacters
        case charactersResponse([Character])
        case selectCharacter(Character)
        case previewVoice(Character)
        case stopPreview
        case dismiss

        @CasePathable
        enum Delegate {
            case dismiss
            case selectCharacter(Character)
        }

        case delegate(Delegate)
    }

    @Dependency(\.alarmRepository) var alarmRepository
    @Dependency(\.audioClient) var audioClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .loadCharacters:
                return .run { send in
                    do {
                        let characters = try await alarmRepository.loadCharacters()
                        await send(.charactersResponse(characters))
                    } catch {
                        await send(.charactersResponse([]))
                    }
                }

            case let .charactersResponse(characters):
                state.characters = characters
                return .none

            case let .selectCharacter(character):
                state.selectedCharacterId = character.id
                return .run { send in
                    await send(.delegate(.selectCharacter(character)))
                }

            case let .previewVoice(character):
                state.isPlayingPreview = true
                return .run { send in
                    await audioClient.playWakeClip(character, nil)
                    // Small delay to simulate preview
                    try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                    await send(.stopPreview)
                }

            case .stopPreview:
                state.isPlayingPreview = false
                return .run { _ in
                    await audioClient.stopPlayback()
                }

            case .dismiss:
                return .send(.delegate(.dismiss))

            case .delegate:
                return .none
            }
        }
    }
}

struct CharacterSelectFeatureView: View {
    let store: StoreOf<CharacterSelectFeature>

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(store.characters) { character in
                        CharacterCardView(
                            character: character,
                            isSelected: store.selectedCharacterId == character.id,
                            isPlaying: store.isPlayingPreview
                        ) {
                            store.send(.selectCharacter(character))
                        } onPreview: {
                            store.send(.previewVoice(character))
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("キャラクター選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        store.send(.dismiss)
                    }
                }
            }
            .task {
                await store.send(.loadCharacters).finish()
            }
        }
    }
}

struct CharacterCardView: View {
    let character: Character
    let isSelected: Bool
    let isPlaying: Bool
    let onSelect: () -> Void
    let onPreview: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                // TODO: Replace with actual character image
                Image(systemName: characterIcon(for: character))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .foregroundStyle(characterColor(for: character))
                    .padding(20)
                    .background(
                        Circle()
                            .fill(Color(.systemGray6))
                            .overlay(
                                Circle()
                                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3)
                            )
                    )

                if isPlaying {
                    Circle()
                        .fill(Color.black.opacity(0.5))
                        .frame(width: 120, height: 120)

                    Image(systemName: "speaker.wave.2")
                        .font(.title2)
                        .foregroundStyle(.white)
                }
            }

            Text(character.name)
                .font(.headline)
                .foregroundStyle(isSelected ? .blue : .primary)

            Text(character.personalityType)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Button {
                    onPreview()
                } label: {
                    Image(systemName: "speaker")
                        .foregroundStyle(.blue)
                }
                .disabled(isPlaying)

                Button {
                    onSelect()
                } label: {
                    Text(isSelected ? "選択中" : "選択")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(isSelected ? Color.blue : Color.gray)
                        .clipShape(Capsule())
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }

    private func characterIcon(for character: Character) -> String {
        switch character.personalityType {
        case "gentle": return "person.circle.fill"
        case "tsundere": return "person.circle.fill"
        case "cool": return "person.circle.fill"
        default: return "person.circle"
        }
    }

    private func characterColor(for character: Character) -> Color {
        switch character.personalityType {
        case "gentle": return .green
        case "tsundere": return .pink
        case "cool": return .blue
        default: return .gray
        }
    }
}