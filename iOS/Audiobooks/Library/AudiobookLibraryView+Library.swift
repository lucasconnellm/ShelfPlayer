//
//  AudiobookLibraryView+Library.swift
//  Audiobooks
//
//  Created by Rasmus Krämer on 03.10.23.
//

import SwiftUI
import Defaults
import SPBase

extension AudiobookLibraryView {
    struct LibraryView: View {
        @Environment(\.libraryId) var libraryId
        
        @Default(.audiobooksDisplay) var audiobookDisplay
        @Default(.audiobooksFilter) var audiobooksFilter
        
        @Default(.audiobooksSortOrder) var audiobooksSortOrder
        @Default(.audiobooksAscending) var audiobooksAscending
        
        @State private var failed = false
        @State private var audiobooks = [Audiobook]()
        
        @State private var filteredGenres = [String]()
        
        private var genres: [String] {
            var genres = Set<String>()
            
            for audiobook in audiobooks {
                for genre in audiobook.genres {
                    genres.insert(genre)
                }
            }
            
            return Array(genres)
        }
        private var visibleAudiobooks: [Audiobook] {
            let visible = AudiobookSortFilter.filterSort(audiobooks: audiobooks, filter: audiobooksFilter, order: audiobooksSortOrder, ascending: audiobooksAscending)
            
            if filteredGenres.count == 0 {
                return visible
            }
            
            return visible.filter {
                if $0.genres.count == 0 {
                    return false
                }
                
                let matches = $0.genres.reduce(0, { result, genre in genres.contains(where: { $0 == genre }) ? result + 1 : result })
                return matches == genres.count
            }
        }
        
        var body: some View {
            NavigationStack {
                Group {
                    if audiobooks.isEmpty {
                        if failed {
                            ErrorView()
                        } else {
                            LoadingView()
                        }
                    } else {
                        Group {
                            switch audiobookDisplay {
                                case .grid:
                                    ScrollView {
                                        AudiobookGrid(audiobooks: visibleAudiobooks)
                                            .padding(.horizontal)
                                    }
                                case .list:
                                    List {
                                        AudiobooksList(audiobooks: visibleAudiobooks)
                                    }
                                    .listStyle(.plain)
                            }
                        }
                        .modifier(AudiobookGenreFilterModifier(genres: genres, selected: $filteredGenres))
                    }
                }
                .navigationTitle("title.library")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink(destination: AuthorsView()) {
                            Image(systemName: "person.fill")
                        }
                    }
                    
                    ToolbarItem(placement: .topBarTrailing) {
                        AudiobookSortFilter(display: $audiobookDisplay, filter: $audiobooksFilter, sort: $audiobooksSortOrder, ascending: $audiobooksAscending)
                    }
                }
                .modifier(NowPlayingBarSafeAreaModifier())
                .task { await fetchAudiobooks() }
                .refreshable { await fetchAudiobooks() }
            }
            .modifier(NowPlayingBarModifier())
            .tabItem {
                Label("tab.library", systemImage: "book.fill")
            }
        }
    }
}

// MARK: Helper

extension AudiobookLibraryView.LibraryView {
    func fetchAudiobooks() async {
        failed = false
        
        if let audiobooks = try? await AudiobookshelfClient.shared.getAudiobooks(libraryId: libraryId) {
            self.audiobooks = audiobooks
        } else {
            failed = true
        }
    }
}
