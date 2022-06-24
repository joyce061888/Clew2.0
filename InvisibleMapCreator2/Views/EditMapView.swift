//  EditMapView.swift
//  InvisbleMapCreator2
//
//  Created by Joyce Chung on 6/23/2022.
//  Copyright © 2021 Occam Lab. All rights reserved.
//

import SwiftUI

struct EditMapView: View {
    @State private var showingDeleteConfirmation = false
    var mapName: String
    
    var body: some View {
        Text("Map Name: \(mapName)")
            .font(.title)
            .bold()
         
        // location in this map button
        Button(action: {
            // TODO: put in list of POI/savedlocations in selected map
        }) {
            Text("View Locations in this Map")
                .frame(minWidth: 0, maxWidth: 300)
                .padding()
                .foregroundColor(.black)
                .background(Color.green)
                .cornerRadius(10)
                .font(.system(size: 18, weight: .bold))
                .padding(10)
                .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.green, lineWidth: 4))
        }.padding()
        
        // upload map button
        Button(action: {
            // TODO: upload map to IM app
        }) {
            Text("Upload Map to Invisible Maps")
                .frame(minWidth: 0, maxWidth: 300)
                .padding()
                .foregroundColor(.black)
                .background(Color.orange)
                .cornerRadius(10)
                .font(.system(size: 18, weight: .bold))
                .padding(10)
                .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.orange, lineWidth: 4))
        }.padding()
        
        // delete map button
        Button(action: {
            showingDeleteConfirmation = true
        }) {
            Text("Delete Map")
                .frame(minWidth: 0, maxWidth: 300)
                .padding()
                .foregroundColor(.white)
                .background(Color.red)
                .cornerRadius(10)
                .font(.system(size: 18, weight: .bold))
                .padding(10)
                .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.red, lineWidth: 4))
        }.padding()
        // delete confirmation alert popup message when delete route button is pressed
            .alert(isPresented: $showingDeleteConfirmation) {
                Alert(
                    title: Text("Are you sure?"),
                    primaryButton: .destructive(Text("Delete")) {
                        print("deleting map..")
                        InvisibleMapCreatorController.shared.deleteMap(mapName: mapName)
                    },
                    secondaryButton: .cancel()
                )
            }
        
        // Share map button
        Button(action: {
            // TODO: share map
        }) {
            Text("Share Map")
                .frame(minWidth: 0, maxWidth: 300)
                .padding()
                .foregroundColor(.white)
                .background(Color.blue)
                .cornerRadius(10)
                .font(.system(size: 18, weight: .bold))
                .padding(10)
                .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.blue, lineWidth: 4))
        }.padding()
    }
}

/*
struct EditMapView_Previews: PreviewProvider {
    static var previews: some View {
        EditMapView()
    }
}
*/
