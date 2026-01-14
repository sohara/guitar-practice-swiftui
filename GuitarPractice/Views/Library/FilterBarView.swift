import SwiftUI

struct FilterBarView: View {
    @ObservedObject var appState: AppState
    var isSearchFocused: FocusState<Bool>.Binding

    var body: some View {
        VStack(spacing: 10) {
            // Search field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)

                TextField("Search...", text: $appState.searchText)
                    .font(.custom("SF Mono", size: 13))
                    .textFieldStyle(.plain)
                    .focused(isSearchFocused)
                    .onSubmit {
                        isSearchFocused.wrappedValue = false
                    }

                if !appState.searchText.isEmpty {
                    Button {
                        appState.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )

            // Filter and sort row
            HStack(spacing: 12) {
                // Recent items toggle
                Button {
                    appState.showRecentOnly.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                        Text("Recent")
                            .font(.custom("SF Mono", size: 11))
                    }
                    .foregroundColor(appState.showRecentOnly ? .cyan : .gray)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(appState.showRecentOnly ? Color.cyan.opacity(0.15) : Color.white.opacity(0.05))
                    )
                }
                .buttonStyle(.plain)
                .help("Show only items practiced in last 7 days")

                // Type filter
                Menu {
                    Button("All Types") {
                        appState.typeFilter = nil
                    }
                    Divider()
                    ForEach(ItemType.allCases, id: \.self) { type in
                        Button {
                            appState.typeFilter = type
                        } label: {
                            Label(type.rawValue, systemImage: type.icon)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: appState.typeFilter?.icon ?? "line.3.horizontal.decrease")
                            .font(.system(size: 10))
                        Text(appState.typeFilter?.rawValue ?? "All")
                            .font(.custom("SF Mono", size: 11))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8))
                    }
                    .foregroundColor(.gray)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.05))
                    )
                }
                .menuStyle(.borderlessButton)

                // Sort option
                Menu {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Button {
                            if appState.sortOption == option {
                                appState.sortAscending.toggle()
                            } else {
                                appState.sortOption = option
                                appState.sortAscending = true
                            }
                        } label: {
                            HStack {
                                Text(option.rawValue)
                                if appState.sortOption == option {
                                    Image(systemName: appState.sortAscending ? "chevron.up" : "chevron.down")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 10))
                        Text(appState.sortOption.rawValue)
                            .font(.custom("SF Mono", size: 11))
                        Image(systemName: appState.sortAscending ? "chevron.up" : "chevron.down")
                            .font(.system(size: 8))
                    }
                    .foregroundColor(.gray)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.05))
                    )
                }
                .menuStyle(.borderlessButton)

                Spacer()
            }
        }
    }
}
