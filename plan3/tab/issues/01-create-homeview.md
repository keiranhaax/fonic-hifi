# Step 01: Create HomeView

**Priority:** Implementation Step 1 (Independent, can start immediately)
**File:** Create `Fonic HiFi/Presentation/Views/Home/HomeView.swift`
**Action:** Create new file with data-driven sections
**Lines:** ~150 lines
**Impact:** Adds first tab with Recently Played, Most Listened, and Favorite Albums
**Risk:** LOW (independent, no dependencies)

## Current State

**Status:** ❌ HomeView does not exist

**Current tab structure** (ContentView.swift:21-40):
```swift
TabView {
    LibraryView()      // First tab
        .tabItem { Label("Library", systemImage: "music.note.list") }

    SearchView()       // Second tab
        .tabItem { Label("Search", systemImage: "magnifyingglass") }

    SettingsView()     // Third tab
        .tabItem { Label("Settings", systemImage: "gear") }
}
```

**Problem:** No Home tab for displaying Recently Played, Most Listened, and Favorite Albums

## Target State

**File:** `Fonic HiFi/Presentation/Views/Home/HomeView.swift`

**Structure:**
- SwiftUI view with 3 horizontal scrolling sections
- Loading state with ProgressView
- Empty state with welcome message
- Data hooks (commented) for future implementation
- Reusable components: `HomeSection`, `AlbumCardView`, `EmptyHomeView`

**Data Sections:**
1. **Recently Played** - Horizontal scrolling track carousel
2. **Most Listened** - Horizontal scrolling track carousel
3. **Favorite Albums** - Horizontal scrolling album cards

## Solution

### Complete HomeView.swift Implementation

```swift
//
//  HomeView.swift
//  Fonic HiFi
//
//  iOS 26+ Home tab with data-driven sections
//

import SwiftUI
import SwiftData

@MainActor
struct HomeView: View {
    @Environment(\.dataManager) private var dataManager
    @Environment(\.showingNowPlaying) private var showingNowPlaying

    @State private var recentlyPlayed: [Track] = []
    @State private var mostListened: [Track] = []
    @State private var favoriteAlbums: [Album] = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading your music...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if recentlyPlayed.isEmpty && mostListened.isEmpty && favoriteAlbums.isEmpty {
                    EmptyHomeView()
                } else {
                    ScrollView {
                        VStack(spacing: 32) {
                            if !recentlyPlayed.isEmpty {
                                HomeSection(title: "Recently Played") {
                                    CarouselView(tracks: recentlyPlayed)
                                }
                            }

                            if !mostListened.isEmpty {
                                HomeSection(title: "Most Listened") {
                                    CarouselView(tracks: mostListened)
                                }
                            }

                            if !favoriteAlbums.isEmpty {
                                HomeSection(title: "Favorite Albums") {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 16) {
                                            ForEach(favoriteAlbums) { album in
                                                AlbumCardView(album: album)
                                            }
                                        }
                                        .padding(.horizontal)
                                    }
                                }
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle("Home")
            .task {
                await loadData()
            }
        }
    }

    private func loadData() async {
        isLoading = true
        defer { isLoading = false }

        // Phase 2+: Implement data loading from SwiftData
        // recentlyPlayed = await dataManager.getRecentlyPlayed(limit: 10)
        // mostListened = await dataManager.getMostListened(limit: 10)
        // favoriteAlbums = await dataManager.getFavoriteAlbums(limit: 10)
    }
}

// MARK: - Supporting Views

private struct HomeSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title2.bold())
                .padding(.horizontal)

            content
        }
    }
}

private struct EmptyHomeView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.house")
                .font(.system(size: 60))
                .foregroundStyle(.tertiary)
            Text("Welcome to Fonic HiFi")
                .font(.title3.bold())
            Text("Import music to see your library here")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(minHeight: 300)
    }
}

private struct AlbumCardView: View {
    let album: Album

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 8)
                .fill(.tint.opacity(0.15))
                .frame(width: 160, height: 160)
                .overlay {
                    Image(systemName: "music.note")
                        .font(.title)
                        .foregroundStyle(.tint)
                }

            Text(album.title)
                .font(.callout.bold())
                .lineLimit(1)

            Text(album.albumArtist)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(width: 160)
    }
}

private struct CarouselView: View {
    let tracks: [Track]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(tracks) { track in
                    TrackCardView(track: track)
                }
            }
            .padding(.horizontal)
        }
    }
}

private struct TrackCardView: View {
    let track: Track

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 6)
                .fill(.tint.opacity(0.15))
                .frame(width: 50, height: 50)
                .overlay {
                    Image(systemName: "music.note")
                        .foregroundStyle(.tint)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.callout.bold())
                    .lineLimit(1)

                Text(track.artist)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .frame(width: 250)
        .padding(8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    HomeView()
}
```

## Dependencies

- **Blocks:** None - independent implementation
- **Blocked by:** None - can start immediately
- **Requires:** SwiftData models (Track, Album) - already exist in codebase

## Time Estimate

- Implementation: 2-3 hours
- Testing: 15-20 minutes
- **Total:** 2.5-3.5 hours

## Risk Assessment

- **LOW**: Independent file creation, no impact on existing code
- **No build breaks**: File can be created and compiled without modifying other files
- **Easy rollback**: Simply delete file if issues arise
- **Future-ready**: Data hooks commented for Phase 2+ implementation

## Success Criteria

- [ ] File exists: `Fonic HiFi/Presentation/Views/Home/HomeView.swift`
- [ ] File compiles without errors
- [ ] Build passes: `make build`
- [ ] Preview renders correctly in Xcode
- [ ] Empty state shows welcome message
- [ ] Loading state shows ProgressView
- [ ] Navigation title shows "Home"
- [ ] File has correct target membership (Fonic HiFi target)

## Testing Procedure

### Build Verification
```bash
# Verify file exists
ls "Fonic HiFi/Presentation/Views/Home/HomeView.swift"

# Build project
make build

# Verify no errors
echo $?  # Should be 0
```

### Manual Testing
1. Open Xcode
2. Navigate to HomeView.swift
3. Click Preview button
4. Verify empty state renders
5. Check navigation title shows "Home"

### Preview Testing
- Run `#Preview` at bottom of file
- Verify EmptyHomeView shows "Welcome to Fonic HiFi"
- Verify icon and text render correctly

## Rollback Procedure

```bash
# Delete file
rm "Fonic HiFi/Presentation/Views/Home/HomeView.swift"

# Verify build still passes
make build

# Should return to original 3-tab state
```

**Rollback Time:** ~10 seconds

## Implementation Checklist

### Phase 1: Create File
- [ ] Create directory: `Fonic HiFi/Presentation/Views/Home/`
- [ ] Create file: `HomeView.swift` in above directory
- [ ] Copy complete implementation from solution above
- [ ] Add to Xcode project (File → Add Files to "Fonic HiFi")
- [ ] Verify target membership: "Fonic HiFi" target checked

### Phase 2: Verify Compilation
- [ ] Run `make build`
- [ ] Verify exit code is 0 (success)
- [ ] Check for any Swift compiler warnings
- [ ] Review any deprecation notices

### Phase 3: Test Preview
- [ ] Open HomeView.swift in Xcode
- [ ] Enable Canvas (Cmd+Option+Enter)
- [ ] Verify preview renders
- [ ] Check empty state appearance
- [ ] Verify navigation title

### Phase 4: Documentation
- [ ] Update `plan3/tab/tab.md` progress
- [ ] Mark Step 01 as complete
- [ ] Note any issues encountered

## Related Steps

- **Next Step:** `issues/02-update-contentview-search-state.md`
- **Dependent Steps:** Step 03 (ContentView TabView update) will add HomeView to TabView
- **Future Enhancement:** Hook up real data in Phase 2+ (commented in code)

## Design Rationale

**Why This Design:**
1. **Data-driven**: Ready for real Recently Played, Most Listened, and Favorite Albums data
2. **Loading state**: Shows ProgressView while data loads (better UX)
3. **Empty state**: Welcoming message when library is empty
4. **Horizontal scrolling**: Apple Music-style carousels for each section
5. **Future-ready**: Commented data hooks for Phase 2+ implementation
6. **Reusable components**: `HomeSection`, `AlbumCardView`, `CarouselView`, `TrackCardView` for clean code
7. **Preview support**: `#Preview` for rapid iteration in Xcode

**Matches Sample Code:**
- NavigationStack wrapper (like sample tabs)
- Horizontal scrolling sections (Apple Music pattern)
- Clean separation of concerns (sections, cards, empty states)

---

**Status:** Ready for implementation
**Next:** Proceed to Step 02 after verifying this step's success criteria
