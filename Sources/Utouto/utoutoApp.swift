//
//  utoutoApp.swift
//  utouto
//
//  Created by Doyoung Kim on 1/10/26.
//

import SwiftUI
import ComposableArchitecture

@main
struct utoutoApp: App {
    let store = Store(initialState: AppFeature.State()) {
        AppFeature()
    }

    var body: some Scene {
        WindowGroup {
            AppFeatureView(store: store)
        }
    }
}
