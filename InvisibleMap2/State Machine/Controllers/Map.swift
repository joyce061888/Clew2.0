//
//  Map.swift
//  InvisibleMap2
//
//  Created by Allison Li and Ben Morris on 9/28/21.
//  Copyright © 2021 Occam Lab. All rights reserved.
//

import Foundation
import ARKit
import SwiftGraph

class Map {
    var rawData: RawMap
    var aprilTagDetectionDictionary = Dictionary<Int, AprilTagTracker>()
    var tagDictionary = [Int:RawMap.Vertex]()
    var waypointDictionary = [Int:RawMap.WaypointVertex]()
    var waypointKeyDictionary = [String:Int]()
    let distanceToWaypoint: Float = 1.5
    let tagTiltMin: Float = 0.09
    let tagTiltMax: Float = 0.91
    
    var snapTagsToVertical = true
    var firstTagFound = false
    var pathPlanningGraph: WeightedGraph<String, Float>?
    // odometryDict stores a list of nodes by poseID to their xyz data
    var odometryDict: Dictionary<Int, RawMap.OdomVertex.vector3>?
    
    init?(from data: Data) {
        do {
            self.rawData = try JSONDecoder().decode(RawMap.self, from: data)
        } catch let error {
            print(error)
            return nil
        }
    }
    
    func storeTagsInDictionary() {
        for (tagId, vertex) in rawData.tagVertices.enumerated() {
            if snapTagsToVertical {
                let tagPose = simd_float4x4(translation: simd_float3(vertex.translation.x, vertex.translation.y, vertex.translation.z), rotation: simd_quatf(ix: vertex.rotation.x, iy: vertex.rotation.y, iz: vertex.rotation.z, r: vertex.rotation.w))
                
                // Note that the process of leveling the tag doesn't change translation
                let modifiedOrientation = simd_quatf(tagPose.makeZFlat().alignY())

                var newVertex = vertex
                newVertex.rotation.x = modifiedOrientation.imag.x
                newVertex.rotation.y = modifiedOrientation.imag.y
                newVertex.rotation.z = modifiedOrientation.imag.z
                newVertex.rotation.w = modifiedOrientation.real
                rawData.tagVertices[tagId] = newVertex
            }
            // rebind this variable in case it has changed (e.g., through snapTagsToVertical being true)
            let vertex = rawData.tagVertices[tagId]
            tagDictionary[vertex.id] = vertex
        }
    }
    
    /// Stores the waypoints from firebase in a dictionary to speed up lookup of nearby waypoints
    func storeWaypointsInDictionary(){
        var count: Int = 0
        for vertex in rawData.waypointsVertices {
            waypointDictionary[count] = vertex
            waypointKeyDictionary[vertex.id] = count
            count = count + 1
        }
    }
    
    /// Gets the poseID of the node closest to the current camera position that is not the desired endpoint
    func getClosestGraphNode(to location: simd_float3, ignoring endpoint: Int? = nil) -> Int?{
        // get node closest to the current camera position
        var closestNode: Int = 0
        var minDist = 100000.0
        for node in odometryDict!{
            let nodeVec = simd_float3(node.value.x, node.value.y, node.value.z)
            let dist = simd_distance(nodeVec, location)
            
            if (Double)(dist) < minDist && (endpoint == nil || node.key != endpoint) {
                minDist = (Double)(dist)
                closestNode = node.key
            }
        }
        return closestNode
    }
    
    /// Renders graph used for path planning and initializes dictionary and graph used
    func renderGraphPath(){
        // Initializes dictionary and graph
        odometryDict = Dictionary<Int, RawMap.OdomVertex.vector3>(uniqueKeysWithValues: zip(rawData.odometryVertices.map({$0.poseId}), rawData.odometryVertices.map({$0.translation})))
        pathPlanningGraph = WeightedGraph<String, Float>(vertices: Array(odometryDict!.keys).sorted().map({String($0)}))

        for vertex in rawData.odometryVertices {
            for neighbor in vertex.neighbors{
                // Only render path if it hasn't been rendered yet
                if (neighbor < vertex.poseId){
                    let neighborVertex = odometryDict![neighbor]!
                    
                    let vertexVec = simd_float3(vertex.translation.x, vertex.translation.y, vertex.translation.z)
                    let neighborVertexVec = simd_float3(neighborVertex.x, neighborVertex.y, neighborVertex.z)
                    let total_dist = simd_distance(vertexVec, neighborVertexVec)
        
                    // Adding edge from vertex to neighbor
                    pathPlanningGraph!.addEdge(from: String(vertex.poseId), to:String(neighbor), weight:total_dist)
                }
            }
        }
    }
    
    // Plans a path from the current location to the end and visualizes it in red
    @objc func planPath(from startCoords: simd_float3, to endpointId: Int) -> [String]? {
        if !self.firstTagFound {
            return nil
        }

        let tagLocation = rawData.tagVertices.first(where: {$0.id == endpointId})!.translation
        
        let endpoint = getClosestGraphNode(to: simd_float3(tagLocation.x, tagLocation.y, tagLocation.z))!
        let startpoint = getClosestGraphNode(to: startCoords, ignoring: endpoint)

        let (_, pathDict) = pathPlanningGraph!.dijkstra(root: String(startpoint!), startDistance: Float(0.0))
        print("startpoint:", startpoint!)
        print("endpoint:", endpoint)
        // find path from startpoint to endpointß
        let path: [WeightedEdge<Float>] = pathDictToPath(from: pathPlanningGraph!.indexOfVertex(String(startpoint!))!, to: pathPlanningGraph!.indexOfVertex(String(endpoint))!, pathDict: pathDict)
        let stops: [String] = pathPlanningGraph!.edgesToVertices(edges: path)
        
        return stops
    }
}

struct RawMap: Decodable {
    var tagVertices: [Vertex]
    let odometryVertices: [OdomVertex]
    let waypointsVertices: [WaypointVertex]
    
    enum CodingKeys: String, CodingKey {
        case tagVertices = "tag_vertices"
        case odometryVertices = "odometry_vertices"
        case waypointsVertices = "waypoints_vertices"
    }
    
    struct WaypointVertex: Decodable {
        let id: String
        let translation: vector3
        let rotation: quaternion
        
        enum CodingKeys: String, CodingKey {
            case id
            case translation = "translation"
            case rotation = "rotation"
        }
        
        struct vector3: Decodable {
            let x: Float
            let y: Float
            let z: Float
            
            enum CodingKeys: String, CodingKey {
                case x = "x"
                case y = "y"
                case z = "z"
            }
        }
        
        struct quaternion:Decodable {
            let x: Float
            let y: Float
            let z: Float
            let w: Float
            
            
            enum CodingKeys: String, CodingKey {
                case x = "x"
                case y = "y"
                case z = "z"
                case w = "w"
            }
        }
    }
    
    struct Vertex: Decodable {
        let id: Int
        let translation: vector3
        var rotation: quaternion
        
        enum CodingKeys: String, CodingKey {
            case id
            case translation = "translation"
            case rotation = "rotation"
        }
        
        struct vector3: Decodable {
            let x: Float
            let y: Float
            let z: Float
            
            enum CodingKeys: String, CodingKey {
                case x = "x"
                case y = "y"
                case z = "z"
            }
        }
        
        struct quaternion:Decodable {
            var x: Float
            var y: Float
            var z: Float
            var w: Float
            
            
            enum CodingKeys: String, CodingKey {
                case x = "x"
                case y = "y"
                case z = "z"
                case w = "w"
            }
        }
        
    }
    
    
    struct OdomVertex: Decodable {
        let poseId: Int
        let translation: vector3
        var rotation: quaternion
        var neighbors: [Int] = []

        
        enum CodingKeys: String, CodingKey {
            case poseId
            case translation = "translation"
            case rotation = "rotation"
            case neighbors = "neighbors"
        }
        
        struct vector3: Decodable {
            let x: Float
            let y: Float
            let z: Float
            
            enum CodingKeys: String, CodingKey {
                case x = "x"
                case y = "y"
                case z = "z"
            }
        }
        
        struct quaternion:Decodable {
            var x: Float
            var y: Float
            var z: Float
            var w: Float
            
            
            enum CodingKeys: String, CodingKey {
                case x = "x"
                case y = "y"
                case z = "z"
                case w = "w"
            }
        }
        
    }
}
