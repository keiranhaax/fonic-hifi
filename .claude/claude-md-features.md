# Feature Implementation Notes

## Core Music Library

### Import Flow
1. User selects source → Files app or external drive
2. Scan for supported formats (FLAC, ALAC, AIFF, WAV, APE, DSD)
3. Extract metadata using TagLib
4. Generate quality info (format, bit depth, sample rate)
5. Create DB entries (track, album, artist)
6. Background: waveforms, full artwork, ReplayGain

### Library Views
- **Artists**: Grid with artwork, track/album counts
- **Albums**: Grid with artwork, artist, year
- **Tracks**: List with quality badges, duration
- **Genres**: List with track counts
- **Search**: Full-text across all metadata

### Performance Tips
- Index frequently queried fields
- Lazy load artwork at multiple resolutions
- Use NSCache for in-memory caching
- Background process waveforms
- Batch database operations (500 items)

## Advanced Playback Engine

### Audio Engine Hierarchy
```
AVAudioEngine (primary)
├── Standard formats (MP3, AAC, ALAC, WAV, AIFF)
├── iOS audio session integration
└── Hardware acceleration

AudioKitEngine (secondary)
├── FLAC playback and waveform analysis
├── Advanced DSP pipeline
└── Seamless hand-off from facade

Legacy stub adapters (SFBAudioEngine, FFmpegKit) were removed from the production target.
```

### Bit-Perfect Validation
- Check hardware capabilities
- Match source sample rate/bit depth
- Disable all processing when active
- Display bit-perfect indicator
- Validate with BitPerfectValidatorService

### DSP Pipeline (Phase 1)
- 10-band EQ (32Hz to 16kHz)
- Gain control with ReplayGain
- Sample rate conversion
- Crossfade (configurable)
- All optional based on mode

### Waveform Generation
- Decode in chunks (efficiency)
- Calculate peak/RMS per chunk
- Delta encoding compression
- Base64 storage in DB
- Adaptive detail by performance mode

## Smart Playlists

### Filter Rule Structure
```swift
FilterRule {
  attribute: .artist/.genre/.quality/etc
  operator: .contains/.equals/.greaterThan/etc
  value: Any
  combinator: .and/.or
}
```

### Query Building
- Convert rules to NSPredicates
- Optimize for indexed fields
- Support complex boolean logic
- Real-time preview results
- Background execution for large sets

### Common Presets
- High-res only (bit depth ≥ 24)
- Recently added (last 7 days)
- Never played (play count = 0)
- Favorite artists (custom field)
- Genre combinations

## Metadata Editor

### Single File Editing
- Read tags via TagLib
- Display all standard fields
- Support custom fields
- Artwork management (add/remove/replace)
- Lyrics support (embedded/LRC)
- Non-destructive with backups

### Batch Operations
- Select multiple tracks
- Pattern-based editing
- Find/replace in fields
- Apply artwork to albums
- Preview before applying
- Progress tracking

### CUE Sheet Support
- Parse .cue files
- Split single audio file
- Apply track metadata
- Generate individual files
- Maintain audio quality

### Tag Writing Safety
- Create timestamped backups
- Validate before writing
- Atomic operations
- Rollback on failure
- Preserve unknown tags

## UI/UX Guidelines

### Player Interface
- Prominent artwork display
- Quality indicator badges
- Waveform visualization
- Smooth gesture controls
- Queue management

### Dark Mode Design
- True black backgrounds (#000000)
- High contrast elements
- Subtle gradients
- Minimal borders
- Focus on content

### Animation Guidelines
- 60fps target
- Spring animations preferred
- Respect reduced motion
- Loading states for all async
- Smooth transitions

### Accessibility
- VoiceOver: descriptive labels
- Dynamic Type: all text scales
- Color: don't rely on color alone
- Haptics: appropriate feedback
- Keyboard: full navigation

## Performance Modes

### Balanced (Default)
- Efficient decoding
- Medium waveforms
- Smart caching
- ~8 hour battery life

### Maximum Quality
- Bit-perfect priority
- Full resolution waveforms
- No lossy processing
- ~4 hour battery life

### Battery Saver
- Downsample if needed
- Minimal visuals
- Aggressive caching
- ~12 hour battery life

## Error Handling

### User-Facing Errors
- "Cannot read file" → Check permissions
- "Format not supported" → List supported
- "Storage full" → Show space needed
- "Metadata save failed" → Offer retry
- Always provide actionable solutions

### Recovery Strategies
- Auto-retry transient errors
- Fallback to cached data
- Graceful degradation
- Queue persistence
- Session restoration