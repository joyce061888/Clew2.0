//
//  DebugHelpers.swift
//  InvisibleMap
//
//  Created by Paul Ruvolo on 8/11/20.
//  Copyright © 2020 Occam Lab. All rights reserved.
//

import Foundation
import UIKit
import ARKit
import GLKit

/// Adds or updates a tag node when a tag is detected
///
/// - Parameter tag: the april tag detected by the visual servoing platform
func addTagDetectionNode(detectionNodes: SCNNode, snapTagsToVertical: Bool, doKalman: Bool, aprilTagDetectionDictionary: inout Dictionary<Int, AprilTagTracker>, tag: AprilTags, cameraTransform: simd_float4x4) {
 //   let generator = UIImpactFeedbackGenerator(style: .heavy)
//    generator.impactOccurred()
    let pose = tag.poseData
    let transVar = simd_float3(Float(tag.transVecVar.0), Float(tag.transVecVar.1), Float(tag.transVecVar.2))
    let quatVar = simd_float4(x: Float(tag.quatVar.0), y: Float(tag.quatVar.1), z: Float(tag.quatVar.2), w: Float(tag.quatVar.3))

    let originalTagPose = simd_float4x4(pose)
    
    let aprilTagToARKit = simd_float4x4(diagonal:simd_float4(1, -1, -1, 1))
    // convert from April Tag's convention to ARKit's convention
    let tagPoseARKit = aprilTagToARKit*originalTagPose
    // project into world coordinates
    var scenePose = cameraTransform*tagPoseARKit

    if snapTagsToVertical {
        scenePose = scenePose.makeZFlat().alignY()
    }
    let transVarMatrix = simd_float3x3(diagonal: transVar)
    let quatVarMatrix = simd_float4x4(diagonal: quatVar)

    // this is the linear transform that takes the original tag pose to the final world pose
    let linearTransform = scenePose*originalTagPose.inverse
    let q = simd_quatf(linearTransform)

    let quatMultiplyAsLinearTransform =
        simd_float4x4(columns: (simd_float4(q.vector.w, q.vector.z, -q.vector.y, -q.vector.x),
                                simd_float4(-q.vector.z, q.vector.w, q.vector.x, -q.vector.y),
                                simd_float4(q.vector.y, -q.vector.x, q.vector.w, -q.vector.z),
                                simd_float4(q.vector.x, q.vector.y, q.vector.z, q.vector.w)))
    let sceneTransVar = linearTransform.getUpper3x3()*transVarMatrix*linearTransform.getUpper3x3().transpose
    let sceneQuatVar = quatMultiplyAsLinearTransform*quatVarMatrix*quatMultiplyAsLinearTransform.transpose

    let scenePoseQuat = simd_quatf(scenePose)
    let scenePoseTranslation = scenePose.getTrans()
    let aprilTagTracker = aprilTagDetectionDictionary[Int(tag.number), default: AprilTagTracker(sceneView, tagId: Int(tag.number))]
    aprilTagDetectionDictionary[Int(tag.number)] = aprilTagTracker

    // TODO: need some sort of logic to discard old detections.  One method that seems good would be to add some process noise (Q_k non-zero)
    aprilTagTracker.updateTagPoseMeans(id: Int(tag.number), detectedPosition: scenePoseTranslation, detectedPositionVar: sceneTransVar, detectedQuat: scenePoseQuat, detectedQuatVar: sceneQuatVar, doKalman: doKalman)
    
    let tagNode: SCNNode
    if let existingTagNode = detectionNodes.childNode(withName: "Tag_\(String(tag.number))", recursively: false)  {
        tagNode = existingTagNode
        tagNode.simdPosition = aprilTagTracker.tagPosition
        tagNode.simdOrientation = aprilTagTracker.tagOrientation
    } else {
        tagNode = SCNNode()
        tagNode.simdPosition = aprilTagTracker.tagPosition
        tagNode.simdOrientation = aprilTagTracker.tagOrientation
        tagNode.geometry = SCNBox(width: 0.19, height: 0.19, length: 0.05, chamferRadius: 0)
        tagNode.name = "Tag_\(String(tag.number))"
        tagNode.geometry?.firstMaterial?.diffuse.contents = UIColor.cyan
        detectionNodes.addChildNode(tagNode)
    }
    
    /// Adds axes to the tag to aid in the visualization
    let xAxis = SCNNode(geometry: SCNBox(width: 1.0, height: 0.05, length: 0.05, chamferRadius: 0))
    xAxis.position = SCNVector3.init(0.75, 0, 0)
    xAxis.geometry?.firstMaterial?.diffuse.contents = UIColor.red
    let yAxis = SCNNode(geometry: SCNBox(width: 0.05, height: 1.0, length: 0.05, chamferRadius: 0))
    yAxis.position = SCNVector3.init(0, 0.75, 0)
    yAxis.geometry?.firstMaterial?.diffuse.contents = UIColor.green
    let zAxis = SCNNode(geometry: SCNBox(width: 0.05, height: 0.05, length: 1.0, chamferRadius: 0))
    zAxis.position = SCNVector3.init(0, 0, 0.75)
    zAxis.geometry?.firstMaterial?.diffuse.contents = UIColor.blue
    tagNode.addChildNode(xAxis)
    tagNode.addChildNode(yAxis)
    tagNode.addChildNode(zAxis)
}
