# iOS 26 Research Multi-Tier Search Strategy

## Strategy Overview

This document demonstrates the multi-tier search approach for verifying iOS 26 information.

## Example 1: Feature Found in Tier 1 (Fast Path)

### User Query
"What's the syntax for GlassEffectContainer in iOS 26?"

### Execution

**Tier 1: Apple RAG Search**
```
mcp__apple-rag-mcp__search(
    query: "iOS 26 GlassEffectContainer SwiftUI API",
    result_count: 5
)
```

**Result:** ✅ FOUND (3 seconds)

```swift
@MainActor @preconcurrency struct GlassEffectContainer<Content> where Content : View

// Usage
GlassEffectContainer {
    // Views with .glassEffect() modifiers
}
```

**Decision:** Stop here. Tag [Verified-Apple-iOS26]. Cite source.

**Total Time:** 3 seconds

---

## Example 2: Feature Found in Tier 2 (Navigation Path)

### User Query
"Are there iOS 26 release notes for SwiftData?"

### Execution

**Tier 1: Apple RAG Search**
```
mcp__apple-rag-mcp__search(
    query: "iOS 26 SwiftData release notes changes",
    result_count: 5
)
```

**Result:** ⚠️ Partial (found general info but not release notes specifically)

**Tier 2: Sosumi Search**
```
mcp__sosumi__searchAppleDocumentation(
    query: "iOS 26 release notes SwiftData"
)
```

**Result:** ✅ FOUND (5 seconds)
- URL: https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-26-release-notes
- Found specific SwiftData section in release notes

**Tier 3: Fetch Complete Document**
```
mcp__sosumi__fetchAppleDocumentation(
    path: "ios-ipados-release-notes/ios-ipados-26-release-notes"
)
```

**Result:** ✅ COMPLETE (8 seconds)
- Full release notes with SwiftData section

**Decision:** Tag [Verified-Apple-iOS26]. Cite release notes URL.

**Total Time:** 3 + 5 + 8 = 16 seconds

---

## Example 3: Feature Not Found (Searched-Not-Found)

### User Query
"Does iOS 26 have built-in quantum encryption APIs?"

### Execution

**Tier 1: Apple RAG Search**
```
mcp__apple-rag-mcp__search(
    query: "iOS 26 quantum encryption API cryptography",
    result_count: 5
)
```

**Result:** ❌ NOT FOUND (3 seconds)

**Tier 2: Sosumi Search**
```
mcp__sosumi__searchAppleDocumentation(
    query: "iOS 26 quantum encryption"
)
```

**Result:** ❌ NOT FOUND (5 seconds)

**Tier 4: Web Search (Fallback)**
```
mcp__brave-search__brave_web_search(
    query: "iOS 26 quantum encryption site:developer.apple.com 2025",
    count: 5
)
```

**Result:** ❌ NOT FOUND (4 seconds)

**Decision:** Tag [Searched-Not-Found]. Acknowledge search performed.

**Response:**
```
I searched Apple's iOS 26 documentation across multiple sources but could
not find information about built-in quantum encryption APIs [Searched-Not-Found].

This feature may not exist in iOS 26, or documentation may not be publicly
available yet. Standard encryption APIs (CryptoKit, Security framework)
remain available.
```

**Total Time:** 3 + 5 + 4 = 12 seconds

---

## Example 4: WWDC Session Reference

### User Query
"How should I use Liquid Glass in my custom controls?"

### Execution

**Tier 1: Apple RAG Search**
```
mcp__apple-rag-mcp__search(
    query: "iOS 26 Liquid Glass custom controls best practices WWDC",
    result_count: 5
)
```

**Result:** ✅ FOUND with WWDC content (4 seconds)

**Key Finding:**
- WWDC25 Session 323: "Build a SwiftUI app with the new design"
- Timestamp: 19:21 - Custom controls with Liquid Glass
- Recommendation: Use `.interactive()` modifier for custom controls

**Decision:** Tag [Verified-WWDC25]. Include session number and timestamp.

**Response:**
```
According to WWDC25 Session 323 [Verified-WWDC25], for custom controls
you should add the `.interactive()` modifier to make Liquid Glass react
to user interaction:

```swift
Text("Custom Button")
    .glassEffect(.regular.interactive())
```

This applies the same responsive effects (scaling, bouncing, shimmering)
that standard controls use.

Source: WWDC25 Session 323 "Build a SwiftUI app with the new design"
Timestamp: 19:21
URL: https://developer.apple.com/videos/play/wwdc2025/323/
```

**Total Time:** 4 seconds

---

## Example 5: Inference vs Verification

### User Query (Hypothetical)
"Does NavigationStack in iOS 26 support custom transitions?"

### Without Skill (Inference-Only)
```
Based on my knowledge, NavigationStack supports custom transitions through
the .navigationTransition() modifier...
```
**Problem:** This is from pre-January 2025 knowledge. API may have changed.

### With Skill (Verified)
```
Tier 1: Apple RAG Search
Query: "iOS 26 NavigationStack custom transitions API"

Result: Found updated documentation showing iOS 26 uses
.navigationTransition() with new morphing capabilities.

Response: According to Apple's iOS 26 documentation [Verified-Apple-iOS26],
NavigationStack supports custom transitions using .navigationTransition()
with enhanced morphing effects for Liquid Glass integration.
```

**Benefit:** Verified against actual iOS 26 documentation, not assumptions.

---

## Decision Matrix

```
┌─────────────────────────────────────────┐
│ Search Results Decision Tree            │
└─────────────────────────────────────────┘

Found in Apple Docs (Tier 1-3)?
├─ YES → Tag [Verified-Apple-iOS26]
│        Include source URL
│        High confidence
│
└─ NO → Search WWDC content?
    ├─ YES → Tag [Verified-WWDC25]
    │        Include session + timestamp
    │        High confidence
    │
    └─ NO → Search web (Tier 4)?
        ├─ Found on Apple.com → Tag [Verified-Apple-iOS26]
        │                        Note search path
        │
        ├─ Found elsewhere → Tag [External-Source]
        │                    Include caveat
        │                    Medium confidence
        │
        └─ Not found → Tag [Searched-Not-Found]
                       Acknowledge gaps
                       Suggest alternatives
```

## Performance Benchmarks

**Average Search Times:**
- Tier 1 only: 3-5 seconds
- Tier 1 + 2: 8-10 seconds
- Tier 1 + 2 + 3: 15-20 seconds
- Full multi-tier: 25-35 seconds

**Success Rates (estimated):**
- Tier 1 finds: 70% of queries
- Tier 2 finds: 20% of queries
- Tier 3 finds: 5% of queries
- Not found: 5% of queries

## Best Practices

1. **Start with Tier 1** - Fastest, most comprehensive
2. **Use specific queries** - Include "iOS 26", "2025", framework names
3. **Escalate when needed** - Don't stop at partial results
4. **Always tag results** - Clear verification status
5. **Cite sources** - Include URLs for user verification
6. **Acknowledge gaps** - Use [Searched-Not-Found] when appropriate
