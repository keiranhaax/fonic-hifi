# Widget contract comparison

Compared the app and widget copies at repository commit `459db9bfd18d17960e8fd2ff8defc4701085532e`.

## WidgetConstants.swift

- App SHA-256: `085ead37d51a6d7c26a4c74ae298982d34704684ee0c496bbb8bf42e0ebbee7a`
- Widget SHA-256: `be667d8717502637a09141bc3a24dd086d1de0657dc1d2a51f90585d1218ffb7`
- Body from line 8 onward identical: **yes**
- Unified diff line count: 13

```diff
--- Fonic HiFi/Shared/WidgetConstants.swift
+++ Fonic HiFi Widget/Shared/WidgetConstants.swift
@@ -1,8 +1,8 @@
 //
 //  WidgetConstants.swift
-//  Fonic HiFi
+//  Fonic HiFi Widget
 //
-//  Created by Claude on 11/26/25.
+//  Standalone copy for widget extension (no main app dependencies)
 //

 import Foundation
```

## WidgetPlaybackState.swift

- App SHA-256: `afae0b37d4f52e04ad7effd4caa6c4f3c8e7fd5c15b387d70da05689f8304e0a`
- Widget SHA-256: `0f365193f2ad0d3fa5c450a5bb7302da9a93709aa1aaf4a3da42cf85dd272c10`
- Body from line 8 onward identical: **yes**
- Unified diff line count: 13

```diff
--- Fonic HiFi/Shared/WidgetPlaybackState.swift
+++ Fonic HiFi Widget/Shared/WidgetPlaybackState.swift
@@ -1,8 +1,8 @@
 //
 //  WidgetPlaybackState.swift
-//  Fonic HiFi
+//  Fonic HiFi Widget
 //
-//  Created by Claude on 11/26/25.
+//  Standalone copy for widget extension (no main app dependencies)
 //

 import Foundation
```

## WidgetTrackInfo.swift

- App SHA-256: `7fafc32cf0792d7b2e399c5b7dcacb816f634dda21dd5ab58ff920c85ffd2748`
- Widget SHA-256: `0fa0d1d7b3e018bf83d8a962669cc4d6f29a646962960104173ec17eb9832f49`
- Body from line 8 onward identical: **yes**
- Unified diff line count: 13

```diff
--- Fonic HiFi/Shared/WidgetTrackInfo.swift
+++ Fonic HiFi Widget/Shared/WidgetTrackInfo.swift
@@ -1,8 +1,8 @@
 //
 //  WidgetTrackInfo.swift
-//  Fonic HiFi
+//  Fonic HiFi Widget
 //
-//  Created by Claude on 11/26/25.
+//  Standalone copy for widget extension (no main app dependencies)
 //

 import Foundation
```
