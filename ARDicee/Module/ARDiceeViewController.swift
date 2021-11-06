//
//  ViewController.swift
//  ARDicee
//
//  Created by Binaya on 04/11/2021.
//

import UIKit
import SceneKit
import ARKit

class ARDiceeViewController: UIViewController {

    //MARK: - IBOutlets

    @IBOutlet var sceneView: ARSCNView!
    
    //MARK: - Instance properties

    private var diceArray = [SCNNode]()
    
    //MARK: - Lifecycle methods

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        sceneView.autoenablesDefaultLighting = true
        
        // Enable debug options to show that the plane is being detected using points: Only use in dev mode
//        sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints]
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if ARWorldTrackingConfiguration.isSupported {
        
            // Create a session configuration
            let configuration = ARWorldTrackingConfiguration()
            
            // Enable horizontal plane detection
            configuration.planeDetection = .horizontal
            
            // Run the view's session
            sceneView.session.run(configuration)
            
        }else {
            
            let messageAlertController = UIAlertController(title: "Unsupported", message: "Your device does not support Augmented Reality.", preferredStyle: .alert)
            let closeAction = UIAlertAction(title: "Close", style: .cancel, handler: nil)
            messageAlertController.addAction(closeAction)
            present(messageAlertController, animated: true, completion: nil)
            
        }
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    //MARK: - Instance methods
    
    private func addDice(atLocation location: ARHitTestResult) {
        
        let diceScene = SCNScene(named: "art.scnassets/dice.scn")!
        guard let diceNode = diceScene.rootNode.childNode(withName: "Dice", recursively: true) else {
            print("No child node with the name 'Dice'")
            return
        }
        
        // 4th column(3rd index) is equal to the positions that the user tapped.
        diceNode.position = SCNVector3(location.worldTransform.columns.3.x,
                                       location.worldTransform.columns.3.y + diceNode.boundingSphere.radius,
                                       location.worldTransform.columns.3.z)
        diceArray.append(diceNode)
        sceneView.scene.rootNode.addChildNode(diceNode)
        rollDie(diceNode)
        
    }
    
    private func rollDie(_ die: SCNNode) {
        
        // arc4random_uniform(4) generated random number between 0 - 3 so we're adding 1.
        let randomXRotationDegrees = Float(arc4random_uniform(4) + 1) * (Float.pi / 2)
        let randomZRotationDegrees = Float(arc4random_uniform(4) + 1) * (Float.pi / 2)

        die.runAction(
            
            // Multiplying the degress to rotate by 5 to provide faster rotation. Alternatively, we can decrese the duration.
            SCNAction.rotateBy(x: CGFloat(randomXRotationDegrees * 5),
                               y: 0,
                               z: CGFloat(randomZRotationDegrees * 5),
                               duration: 0.5)
        )
        
    }
    
    private func rollAllDice() {
        
        if !diceArray.isEmpty {
            
            diceArray.forEach { dice in
                self.rollDie(dice)
            }
            
        }
        
    }
    
    private func createPlane(with planeAnchor: ARPlaneAnchor) -> SCNNode {
        
        // Although the type of this property(planeAnchor.extent) is vector_float3(3D), a plane anchor is always two-dimensional, and is always positioned and sized in only the x and z directions relative to its transform position. (That is, the y-component of this vector is always zero.)
        
        let plane = SCNPlane(width: CGFloat(planeAnchor.extent.x), height: CGFloat(planeAnchor.extent.z))
        
        let planeNode = SCNNode()
        
        // Y should be 0 as we want to place this plane on the horizontal detected plane.
        
        planeNode.position = SCNVector3(planeAnchor.center.x, 0, planeAnchor.center.z)
        
        // Note: SCNPlane objects are created as a vertical plane by default with the x = width and the height = y and z = non existent as it is 2D.
        
        // We need to rotate it by 90 degrees on the x-axis (Note that it is 2D(x and y axis)) to make it horizontal. The angle parameter is in radians counterclockwise around the rotation axis.
        
        planeNode.transform = SCNMatrix4MakeRotation(-Float.pi/2, 1, 0, 0)
        
        let planeMaterial = SCNMaterial()
        planeMaterial.diffuse.contents = UIImage(named: "art.scnassets/grid.png") // Apple provided grid.
        plane.materials = [planeMaterial]
        
        planeNode.geometry = plane
        return planeNode
        
    }
    
    // Roll all dice after shaking the device.
    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        rollAllDice()
    }
    
    //MARK: - @IBAction methods

    @IBAction func rollAllBarButtonItemTapped(_ sender: UIBarButtonItem) {
        rollAllDice()
    }
    
    @IBAction func clearBarButtonTapped(_ sender: UIBarButtonItem) {
        
        if !diceArray.isEmpty {
            diceArray.forEach { die in
                die.removeFromParentNode()
            }
            diceArray.removeAll()
        }
        
    }
    
}

//MARK: - ARSCNViewDelegate extension

extension ARDiceeViewController: ARSCNViewDelegate {
    
    // Called when a new plane is detected and an anchor is added by default.
    // Anchor = Similar to a tile on the ground that has a width and a height that we can put virtual objects.
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        
        guard let planeAnchor = anchor as? ARPlaneAnchor else {
            print("Horizontal plane not detected")
            return
        }
        let planeNode = createPlane(with: planeAnchor)
        node.addChildNode(planeNode)
        
    }
    
    // Called when a touch is detected in the view or window. Parameter touches set only have more than 1 UITouch instances when multipleTouchEnabled is set to true which is set to false by default. So, in our app the user's touches will always be the first instance in the set.
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        if let touch = touches.first {
            
            // 2D touched location that the user touches on the sceneView.
            let touchLocation = touch.location(in: sceneView)
            
            // Converting the 2D touch location on the horizontal plane to a 3D location. If a touch happened outside of the horizontal plane, then the array results will be empty.
            
            let results = sceneView.hitTest(touchLocation, types: .existingPlaneUsingExtent)
            
            if let hitResult = results.first {
                addDice(atLocation: hitResult)
            }else {
                print("Touched somewhere other than the plane.")
            }
            
        }
        
    }
    
}
