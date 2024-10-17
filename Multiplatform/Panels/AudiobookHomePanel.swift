//
//  AudiobookListenNowView.swift
//  Multiplatform
//
//  Created by Rasmus Krämer on 23.04.24.
//

import SwiftUI
import Defaults
import ShelfPlayerKit
import SPPlayback

internal struct AudiobookHomePanel: View {
    @Environment(\.library) private var library
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    @Default(.showAuthorsRow) private var showAuthorsRow
    @Default(.disableDiscoverRow) private var disableDiscoverRow
    @Default(.hideFromContinueListening) private var hideFromContinueListening
    
    @State private var _authors = [HomeRow<Author>]()
    @State private var _audiobooks = [HomeRow<Audiobook>]()
    
    @State private var downloaded = [Audiobook]()
    
    @State private var failed = false
    
    private var authors: [HomeRow<Author>] {
        if !showAuthorsRow {
            return []
        }
        
        return _authors
    }
    private var audiobooks: [HomeRow<Audiobook>] {
        _audiobooks.filter {
            guard $0.id == "discover" else {
                return !$0.entities.isEmpty
            }
            
            return !disableDiscoverRow && !$0.entities.isEmpty
        }
    }
    
    var body: some View {
        Group {
            if audiobooks.isEmpty && authors.isEmpty {
                if failed {
                    ErrorView()
                        .refreshable {
                            await fetchItems()
                        }
                } else {
                    LoadingView()
                        .task {
                            await fetchItems()
                        }
                        .refreshable {
                            await fetchItems()
                        }
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(audiobooks) { row in
                            var entities: [Audiobook] {
                                guard row.id == "continue-listening" else {
                                    return row.entities
                                }
                                
                                return row.entities.filter { audiobook in
                                    !hideFromContinueListening.contains { $0.itemId == audiobook.id }
                                }
                            }
                            
                            AudiobookRow(title: row.localizedLabel, small: false, audiobooks: entities)
                        }
                        
                        ForEach(authors) { row in
                            VStack(alignment: .leading, spacing: 0) {
                                RowTitle(title: row.localizedLabel)
                                    .padding(.bottom, 8)
                                    .padding(.horizontal, 20)
                                
                                AuthorGrid(authors: row.entities)
                            }
                        }
                        
                        if !downloaded.isEmpty {
                            AudiobookRow(title: String(localized: "downloads"), small: false, audiobooks: downloaded)
                        }
                    }
                }
                .refreshable {
                    await fetchItems()
                }
                .onReceive(NotificationCenter.default.publisher(for: PlayableItem.finishedNotification)) { _ in
                    Task {
                        await fetchItems()
                    }
                }
            }
        }
        .navigationTitle(library.name)
        .modifier(SelectLibraryModifier(isCompact: horizontalSizeClass == .compact))
        .modifier(NowPlaying.SafeAreaModifier())
    }
    
    private nonisolated func fetchItems() async {
        await MainActor.withAnimation {
            failed = false
        }
        
        Task {
            let libraryID = await library.id
            let downloaded = try OfflineManager.shared.audiobooks().filter { $0.libraryID == libraryID }
            
            await MainActor.withAnimation {
                self.downloaded = downloaded
            }
        }
        Task {
            do {
                let home: ([HomeRow<Audiobook>], [HomeRow<Author>]) = try await AudiobookshelfClient.shared.home(libraryID: library.id)
                
                await MainActor.withAnimation {
                    _authors = home.1
                    _audiobooks = home.0
                }
            } catch {
                await MainActor.withAnimation {
                    failed = false
                }
            }
        }
    }
}

#Preview {
    AudiobookHomePanel()
}
