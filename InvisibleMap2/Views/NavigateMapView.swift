//
//  NavigateMapView.swift
//  InvisibleMap2
//
//  Created by tad on 11/12/21.
//  Copyright © 2021 Occam Lab. All rights reserved.
//

import SwiftUI
import FirebaseAuth

// Describes all the instructions that will exist on-screen for the user
enum InstructionType: Equatable {
    case findTag(startTime: Double)  // initial instructions when navigate map screen is opened
    case tagFound(startTime: Double)  // pops up each time a tag is found during navigation
    case destinationReached(startTime: Double)  // feedback that user has reached their endpoint
    case none  // when there are no instructions/feedback to display

    var text: String? {
        get {
            switch self {
            case .findTag: return "Point your camera at a tag \nnearby and START TAG DETECTION to start navigation."
            case .tagFound: return "Tag detected. STOP TAG DETECTION until you reach the next tag. When you reach the next tag along the route, START TAG DETECTION for it."
            case .destinationReached: return "You have arrived at your destination!"
            case .none: return nil
            }
        }
        // Set start times for each instruction text so that it shows on the screen for a set amount of time (set in transition func).
        set {
            switch self {
            case .findTag: self = .findTag(startTime: NSDate().timeIntervalSince1970)
            case .tagFound: self = .tagFound(startTime: NSDate().timeIntervalSince1970)
            case .destinationReached: self = .destinationReached(startTime: NSDate().timeIntervalSince1970)
            case .none: self = .none
            }
        }
    }
    
    // To get start time of when the instructions were displayed
    func getStartTime() -> Double {
        switch self {
        case .findTag(let startTime), .tagFound(let startTime), .destinationReached(let startTime):
            return startTime
        default:
            return -1
        }
    }
    
    // when to display instructions/feedback text and to control how long it stays on screen
 /*   mutating func transition(tagFound: Bool) {
        let previousInstruction = self
        switch self {
        case .findTag:
            if InvisibleMapController.shared.mapNavigator
        case .tagFound:
            
        case .destinationReached:
            
        case .none:
            
        }
        
        if self != previousInstruction {
            let instructions = self.text
            if locationRequested || markTagRequested {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    UIAccessibility.post(notification: .announcement, argument: instructions)
                }
            } else {
                UIAccessibility.post(notification: .announcement, argument: instructions)
            }
        } else {
            let currentTime = NSDate().timeIntervalSince1970
            // time that instructions stay on screen
            if currentTime - self.getStartTime() > 8 {
                self = .none
            }
        }
    } */
}



// Provides persistent storage for on-screen instructions and state variables outside of the view struct
class NavigateGlobalState: ObservableObject {
    @Published var tagFound: Bool
    @Published var instructionWrapper: InstructionType
    
    init() {
        tagFound = false
        instructionWrapper = .findTag(startTime: NSDate().timeIntervalSince1970)
    }
    
    // Navigate view controller commands
    func updateInstructionText() {
    // TODO: if first tag is detected, let tagFound get true, otherwise false and transition the instructionWrapper based on that boolean
    }
}

struct NavigateMapView: View {
    @StateObject var navigateGlobalState = NavigateGlobalState()
    var mapFileName: String
    
 /*   init() {
        print("currentUser is \(Auth.auth().currentUser!.uid)")
        //mapName = ""
        //mapFileName = ""
    } */
    
    var body : some View {
        ZStack {
            BaseNavigationView()
                // Toolbar buttons
                .toolbar(content: {
                    ToolbarItem(placement: .navigationBarLeading) {
                        MapNavigateExitButton(mapFileName: mapFileName)
                    }
                })
            VStack{
                // Show instrcutions if there are any
                if navigateGlobalState.instructionWrapper.text != nil {
                    InstructionOverlay(instruction: $navigateGlobalState.instructionWrapper.text)
                        .animation(.easeInOut)
                }
                TagDetectionButton(navigateGlobalState: navigateGlobalState)
                    .environmentObject(InvisibleMapController.shared.mapNavigator)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .padding()
        }
        .ignoresSafeArea(.keyboard)
    }
}

extension UINavigationController {
    override open func viewDidLoad() {
        super.viewDidLoad()
      
        // Creates a translucent toolbar
        let toolbarAppearance = UIToolbarAppearance()
        toolbarAppearance.configureWithTransparentBackground()
        toolbarAppearance.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.7)
        UIToolbar.appearance().standardAppearance = toolbarAppearance
    }
}

/*
struct NavigateMapView_Previews: PreviewProvider {
    static var previews: some View {
        NavigateMapView()
    }
}
*/
