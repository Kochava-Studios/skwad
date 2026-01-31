//
//  GhosttyProgressState.swift
//  Skwad
//
//  Adapted from aizen (https://github.com/vivy-company/aizen)
//  which provides NSView integration for Ghostty terminal emulator.
//  Originally based on Ghostty (MIT license) by Mitchell Hashimoto.
//
//  Licensed under MIT
//

import Foundation

enum GhosttyProgressState {
    case remove
    case set
    case error
    case indeterminate
    case pause
    case unknown

    init(cState: ghostty_action_progress_report_state_e) {
        switch cState {
        case GHOSTTY_PROGRESS_STATE_REMOVE: self = .remove
        case GHOSTTY_PROGRESS_STATE_SET: self = .set
        case GHOSTTY_PROGRESS_STATE_ERROR: self = .error
        case GHOSTTY_PROGRESS_STATE_INDETERMINATE: self = .indeterminate
        case GHOSTTY_PROGRESS_STATE_PAUSE: self = .pause
        default: self = .unknown
        }
    }
}
