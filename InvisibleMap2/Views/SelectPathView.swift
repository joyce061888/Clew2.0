//
//  SelectPathView.swift
//  InvisibleMap2
//
//  Created by occamlab on 11/30/21.
//  Copyright © 2021 Occam Lab. All rights reserved.
//

import SwiftUI

struct SelectPathView: View {
    @ObservedObject var mapNavigator = InvisibleMapController.shared.mapNavigator
    var mapName: String
    
    var body: some View {
        NavigationView {
            if mapNavigator.map != nil {
                VStack {
                    Text("Map Name: \(mapName)")
                        .font(.title)
                        .bold()
                    // populate list of tag locations of selected map
                    // TODO: Instead of tag locations, this should be a list of POI/saved locations on the map 
                    List {
                        ForEach(Array(mapNavigator.map.tagDictionary.keys), id: \.self) { location in
                            NavigationLink(destination: NavigateMapView().onAppear() {
                                InvisibleMapController.shared.process(event: .PathSelected(tagId: location))
                            }) {
                                Text("\(location)")
                            }
                        }
                    }
                }
            }
        }
    }
}

/*
struct SelectPathView_Previews: PreviewProvider {
    static var previews: some View {
        SelectPathView()
    }
} */
