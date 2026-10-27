//
//  EllioApp.swift
//  Ellio
//
//  Created by Ethan Soh on 5/4/26.
//

import SwiftUI

@main
struct EllioApp: App {
    init() {
        AlarmScheduler.requestAuthorization()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
