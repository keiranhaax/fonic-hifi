//
//  FonicWidgetBundle.swift
//  Fonic HiFi Widget
//
//  Created by Claude on 11/26/25.
//

import SwiftUI
import WidgetKit

@main
struct FonicWidgetBundle: WidgetBundle {
    var body: some Widget {
        // Home Screen and Lock Screen widgets
        NowPlayingWidget()

        // Live Activity (Dynamic Island + Lock Screen banner)
        NowPlayingActivityConfiguration()
    }
}
