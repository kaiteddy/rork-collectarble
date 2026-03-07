import SwiftUI
import SceneKit
import UIKit

struct CardCollectionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCard: CollectibleCard?
    @State private var showARExperience = false
    @State private var selectedCreatureId: String = ""

    let cards: [CollectibleCard] = CollectibleCard.sampleCards

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 20)], spacing: 24) {
                    ForEach(cards) { card in
                        Card3DPreview(card: card)
                            .frame(height: 240)
                            .onTapGesture {
                                selectedCard = card
                            }
                    }
                }
                .padding()
            }
            .navigationTitle("My Collection")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $selectedCard) { card in
                CardDetailView(card: card, showARExperience: $showARExperience, selectedCreatureId: $selectedCreatureId)
            }
            .fullScreenCover(isPresented: $showARExperience) {
                ARExperienceView(isPresented: $showARExperience, initialCreatureId: selectedCreatureId, startInThrowMode: true)
            }
        }
    }
}

// MARK: - 3D Card Preview with rotation

struct Card3DPreview: View {
    let card: CollectibleCard
    @State private var rotation: Double = 0
    @State private var isDragging = false

    var body: some View {
        VStack(spacing: 8) {
            // Use the appropriate card view based on creature
            if card.creatureId == "charizard" {
                CharizardCardView(rotation: $rotation)
                    .frame(height: 180)
                    .clipShape(.rect(cornerRadius: 12))
                    .shadow(color: .orange.opacity(0.6), radius: 12, y: 6)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                isDragging = true
                                rotation += value.translation.width * 0.5
                            }
                            .onEnded { _ in
                                isDragging = false
                            }
                    )
            } else {
                SceneKitCardView(card: card, rotation: $rotation)
                    .frame(height: 180)
                    .clipShape(.rect(cornerRadius: 12))
                    .shadow(color: card.displayColor.opacity(0.4), radius: 10, y: 5)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                isDragging = true
                                rotation += value.translation.width * 0.5
                            }
                            .onEnded { _ in
                                isDragging = false
                            }
                    )
            }

            Text(card.name)
                .font(.caption.weight(.semibold))

            HStack(spacing: 4) {
                Image(systemName: card.elementSymbol)
                    .font(.caption2)
                    .foregroundStyle(card.displayColor)
                Text(card.rarity.rawValue)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Charizard 3D USDZ Card View

struct CharizardCardView: UIViewRepresentable {
    @Binding var rotation: Double

    func makeUIView(context: Context) -> SCNView {
        let sceneView = SCNView()
        sceneView.backgroundColor = .clear
        sceneView.antialiasingMode = .multisampling4X
        sceneView.allowsCameraControl = false

        // Try to load the USDZ file
        if let url = Card3DModelService.modelURL(for: "charizard") {
            loadUSDZModel(sceneView: sceneView, url: url)
        } else {
            // Try alternative file names directly
            let possibleNames = [
                "Pokemon_TCG_Charizard_1st_Edition",
                "PokemonTCGCharizard1stEdition",
                "pokemon_tcg_charizard_1st_edition",
                "Charizard_Card",
                "charizard_card"
            ]

            var loaded = false
            for name in possibleNames {
                if let url = Bundle.main.url(forResource: name, withExtension: "usdz") {
                    print("DEBUG: Found Charizard USDZ at: \(url)")
                    loadUSDZModel(sceneView: sceneView, url: url)
                    loaded = true
                    break
                }
            }

            if !loaded {
                print("DEBUG: Charizard USDZ not found, listing bundle contents...")
                listBundleUSDZFiles()
                createFallbackCard(sceneView: sceneView)
            }
        }

        return sceneView
    }

    private func listBundleUSDZFiles() {
        if let resourcePath = Bundle.main.resourcePath {
            do {
                let files = try FileManager.default.contentsOfDirectory(atPath: resourcePath)
                let usdzFiles = files.filter { $0.hasSuffix(".usdz") }
                print("DEBUG: USDZ files in bundle: \(usdzFiles)")
            } catch {
                print("DEBUG: Could not list bundle contents: \(error)")
            }
        }
    }

    private func loadUSDZModel(sceneView: SCNView, url: URL) {
        do {
            let loadedScene = try SCNScene(url: url, options: [
                .checkConsistency: true,
                .flattenScene: false
            ])

            let displayScene = SCNScene()

            // Create container node for rotation
            let containerNode = SCNNode()
            containerNode.name = "card"

            // Clone all content from loaded scene
            for child in loadedScene.rootNode.childNodes {
                containerNode.addChildNode(child.clone())
            }

            // Calculate bounds and scale appropriately
            let (minVec, maxVec) = containerNode.boundingBox
            let width = maxVec.x - minVec.x
            let height = maxVec.y - minVec.y
            let depth = maxVec.z - minVec.z
            let maxDim = max(width, max(height, depth))

            print("DEBUG: USDZ model bounds - w:\(width) h:\(height) d:\(depth)")

            // Scale to fit in view (aim for ~1.2 units tall)
            if maxDim > 0 {
                let targetSize: Float = 1.2
                let scale = targetSize / maxDim
                containerNode.scale = SCNVector3(scale, scale, scale)
            }

            // Center the model
            let centerX = (minVec.x + maxVec.x) / 2
            let centerY = (minVec.y + maxVec.y) / 2
            let centerZ = (minVec.z + maxVec.z) / 2
            containerNode.pivot = SCNMatrix4MakeTranslation(centerX, centerY, centerZ)

            // Rotate to stand upright and show front face
            containerNode.eulerAngles.x = -.pi / 2  // Stand upright
            containerNode.eulerAngles.y = .pi       // Show front face (rotate 180 on Y)
            containerNode.eulerAngles.z = .pi       // Flip right-side up

            displayScene.rootNode.addChildNode(containerNode)

            // Setup lighting for metallic/holographic card
            let keyLight = SCNNode()
            keyLight.light = SCNLight()
            keyLight.light?.type = .directional
            keyLight.light?.intensity = 1200
            keyLight.light?.color = UIColor.white
            keyLight.position = SCNVector3(2, 3, 4)
            keyLight.look(at: SCNVector3(0, 0, 0))
            displayScene.rootNode.addChildNode(keyLight)

            let fillLight = SCNNode()
            fillLight.light = SCNLight()
            fillLight.light?.type = .directional
            fillLight.light?.intensity = 600
            fillLight.light?.color = UIColor(white: 0.95, alpha: 1)
            fillLight.position = SCNVector3(-2, 2, 3)
            fillLight.look(at: SCNVector3(0, 0, 0))
            displayScene.rootNode.addChildNode(fillLight)

            let backLight = SCNNode()
            backLight.light = SCNLight()
            backLight.light?.type = .directional
            backLight.light?.intensity = 400
            backLight.position = SCNVector3(0, 1, -3)
            backLight.look(at: SCNVector3(0, 0, 0))
            displayScene.rootNode.addChildNode(backLight)

            let ambient = SCNNode()
            ambient.light = SCNLight()
            ambient.light?.type = .ambient
            ambient.light?.intensity = 400
            ambient.light?.color = UIColor(white: 0.9, alpha: 1)
            displayScene.rootNode.addChildNode(ambient)

            // Camera
            let cameraNode = SCNNode()
            cameraNode.camera = SCNCamera()
            cameraNode.camera?.fieldOfView = 35
            cameraNode.position = SCNVector3(0, 0, 2.5)
            cameraNode.look(at: SCNVector3(0, 0, 0))
            displayScene.rootNode.addChildNode(cameraNode)

            sceneView.scene = displayScene
            sceneView.pointOfView = cameraNode
            sceneView.autoenablesDefaultLighting = false

            print("DEBUG: Charizard USDZ loaded successfully!")

        } catch {
            print("DEBUG: Failed to load Charizard USDZ: \(error)")
            createFallbackCard(sceneView: sceneView)
        }
    }

    private func createFallbackCard(sceneView: SCNView) {
        print("DEBUG: Using fallback generated card")

        let scene = SCNScene()

        // Create card geometry
        let cardGeometry = SCNBox(width: 0.63, height: 0.88, length: 0.015, chamferRadius: 0.015)

        // Front material with fire gradient
        let frontMaterial = SCNMaterial()
        frontMaterial.diffuse.contents = createFallbackFront()
        frontMaterial.metalness.contents = 0.6
        frontMaterial.roughness.contents = 0.25
        frontMaterial.lightingModel = .physicallyBased

        // Back material
        let backMaterial = SCNMaterial()
        backMaterial.diffuse.contents = UIColor(red: 0.1, green: 0.15, blue: 0.4, alpha: 1)
        backMaterial.metalness.contents = 0.3
        backMaterial.roughness.contents = 0.4

        // Edge material (gold)
        let edgeMaterial = SCNMaterial()
        edgeMaterial.diffuse.contents = UIColor(red: 1, green: 0.8, blue: 0.2, alpha: 1)
        edgeMaterial.metalness.contents = 0.8
        edgeMaterial.roughness.contents = 0.15

        cardGeometry.materials = [edgeMaterial, edgeMaterial, edgeMaterial, edgeMaterial, frontMaterial, backMaterial]

        let cardNode = SCNNode(geometry: cardGeometry)
        cardNode.name = "card"
        scene.rootNode.addChildNode(cardNode)

        // Lighting
        let keyLight = SCNNode()
        keyLight.light = SCNLight()
        keyLight.light?.type = .directional
        keyLight.light?.intensity = 1000
        keyLight.position = SCNVector3(1, 2, 2)
        keyLight.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(keyLight)

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 400
        scene.rootNode.addChildNode(ambient)

        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 35
        cameraNode.position = SCNVector3(0, 0, 2)
        scene.rootNode.addChildNode(cameraNode)

        sceneView.scene = scene
        sceneView.pointOfView = cameraNode
    }

    private func createFallbackFront() -> UIImage {
        let size = CGSize(width: 630, height: 880)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            let ctx = context.cgContext

            // Fire gradient
            let colors: [CGColor] = [
                UIColor(red: 1.0, green: 0.5, blue: 0.1, alpha: 1).cgColor,
                UIColor(red: 0.9, green: 0.25, blue: 0.0, alpha: 1).cgColor,
                UIColor(red: 0.6, green: 0.1, blue: 0.0, alpha: 1).cgColor
            ]
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 0.5, 1])!
            ctx.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])

            // Gold border
            ctx.setStrokeColor(UIColor(red: 1, green: 0.84, blue: 0, alpha: 1).cgColor)
            ctx.setLineWidth(16)
            ctx.stroke(CGRect(x: 12, y: 12, width: size.width - 24, height: size.height - 24))

            // Charizard text
            let nameAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 52),
                .foregroundColor: UIColor.white,
                .strokeColor: UIColor.black,
                .strokeWidth: -2
            ]
            "Charizard".draw(at: CGPoint(x: 120, y: 50), withAttributes: nameAttrs)

            // Dragon emoji
            let dragonAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 200)]
            "🐉".draw(at: CGPoint(x: size.width/2 - 100, y: 200), withAttributes: dragonAttrs)

            // 1ST EDITION
            let editionAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 18),
                .foregroundColor: UIColor.black
            ]
            ctx.setFillColor(UIColor(red: 1, green: 0.84, blue: 0, alpha: 1).cgColor)
            ctx.fill(CGRect(x: 40, y: 55, width: 100, height: 26))
            "1ST EDITION".draw(at: CGPoint(x: 45, y: 58), withAttributes: editionAttrs)
        }
    }

    func updateUIView(_ sceneView: SCNView, context: Context) {
        if let cardNode = sceneView.scene?.rootNode.childNode(withName: "card", recursively: true) {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.05
            // Keep the X rotation to stand upright, Z to flip right-side up, Y for user drag + front face
            cardNode.eulerAngles = SCNVector3(
                -.pi / 2,  // Keep card upright
                Float(rotation * .pi / 180) + .pi,  // User rotation + show front face
                .pi  // Keep flipped right-side up
            )
            SCNTransaction.commit()
        }
    }
}

// MARK: - SceneKit Card View

struct SceneKitCardView: UIViewRepresentable {
    let card: CollectibleCard
    @Binding var rotation: Double

    func makeUIView(context: Context) -> SCNView {
        let sceneView = SCNView()
        sceneView.backgroundColor = .clear
        sceneView.autoenablesDefaultLighting = true
        sceneView.allowsCameraControl = false

        let scene = SCNScene()

        // Create card geometry (trading card proportions: 63mm x 88mm)
        let cardGeometry = SCNBox(width: 0.63, height: 0.88, length: 0.02, chamferRadius: 0.02)

        // Create materials - use generated card designs
        let frontMaterial = SCNMaterial()
        frontMaterial.diffuse.contents = createCardFront(for: card)
        frontMaterial.lightingModel = .physicallyBased
        frontMaterial.metalness.contents = card.isHolographic ? 0.5 : 0.2
        frontMaterial.roughness.contents = card.isHolographic ? 0.3 : 0.5

        let backMaterial = SCNMaterial()
        backMaterial.diffuse.contents = createCardBack(for: card)
        backMaterial.lightingModel = .physicallyBased
        backMaterial.metalness.contents = 0.3
        backMaterial.roughness.contents = 0.4

        let edgeMaterial = SCNMaterial()
        edgeMaterial.diffuse.contents = card.elementColor
        edgeMaterial.metalness.contents = 0.5

        // SCNBox face order: +X, -X, +Y, -Y, +Z (front), -Z (back)
        cardGeometry.materials = [edgeMaterial, edgeMaterial, edgeMaterial, edgeMaterial, frontMaterial, backMaterial]

        let cardNode = SCNNode(geometry: cardGeometry)
        cardNode.name = "card"
        scene.rootNode.addChildNode(cardNode)

        // Add subtle glow for holographic effect
        if card.isHolographic {
            let glowNode = SCNNode(geometry: SCNBox(width: 0.65, height: 0.90, length: 0.01, chamferRadius: 0.02))
            let glowMaterial = SCNMaterial()
            glowMaterial.diffuse.contents = card.elementColor.withAlphaComponent(0.2)
            glowMaterial.emission.contents = card.elementColor.withAlphaComponent(0.3)
            glowNode.geometry?.materials = [glowMaterial]
            glowNode.position = SCNVector3(0, 0, -0.015)
            cardNode.addChildNode(glowNode)
        }

        // Camera
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(0, 0, 1.5)
        scene.rootNode.addChildNode(cameraNode)

        sceneView.scene = scene

        return sceneView
    }

    func updateUIView(_ sceneView: SCNView, context: Context) {
        if let cardNode = sceneView.scene?.rootNode.childNode(withName: "card", recursively: false) {
            cardNode.eulerAngles.y = Float(rotation * .pi / 180)
        }
    }

    /// Create the front of the trading card
    private func createCardFront(for card: CollectibleCard) -> UIImage {
        let size = CGSize(width: 630, height: 880)  // High res for quality
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            let ctx = context.cgContext
            let rect = CGRect(origin: .zero, size: size)

            // Card background with gradient
            let colors: [CGColor]
            switch card.element {
            case "Fire":
                colors = [
                    UIColor(red: 1.0, green: 0.3, blue: 0.1, alpha: 1).cgColor,
                    UIColor(red: 0.8, green: 0.2, blue: 0.0, alpha: 1).cgColor,
                    UIColor(red: 0.6, green: 0.1, blue: 0.0, alpha: 1).cgColor
                ]
            case "Ice":
                colors = [
                    UIColor(red: 0.4, green: 0.8, blue: 1.0, alpha: 1).cgColor,
                    UIColor(red: 0.2, green: 0.5, blue: 0.9, alpha: 1).cgColor,
                    UIColor(red: 0.1, green: 0.3, blue: 0.7, alpha: 1).cgColor
                ]
            case "Nature":
                colors = [
                    UIColor(red: 0.3, green: 0.9, blue: 0.4, alpha: 1).cgColor,
                    UIColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1).cgColor,
                    UIColor(red: 0.1, green: 0.5, blue: 0.2, alpha: 1).cgColor
                ]
            case "Sports":
                colors = [
                    UIColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1).cgColor,
                    UIColor(red: 0.1, green: 0.3, blue: 0.6, alpha: 1).cgColor,
                    UIColor(red: 0.05, green: 0.2, blue: 0.4, alpha: 1).cgColor
                ]
            default:
                colors = [card.elementColor.cgColor, card.elementColor.withAlphaComponent(0.7).cgColor]
            }

            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: nil)!
            ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: size.width, y: size.height), options: [])

            // Holographic shimmer effect
            if card.isHolographic {
                ctx.setBlendMode(.overlay)
                for i in 0..<5 {
                    let shimmerRect = CGRect(x: CGFloat(i) * 150 - 50, y: 0, width: 100, height: size.height)
                    ctx.setFillColor(UIColor.white.withAlphaComponent(0.15).cgColor)
                    ctx.fill(shimmerRect)
                }
                ctx.setBlendMode(.normal)
            }

            // Card border
            ctx.setStrokeColor(UIColor.white.cgColor)
            ctx.setLineWidth(8)
            ctx.stroke(rect.insetBy(dx: 20, dy: 20))

            // Inner border
            ctx.setStrokeColor(card.elementColor.withAlphaComponent(0.5).cgColor)
            ctx.setLineWidth(4)
            ctx.stroke(rect.insetBy(dx: 35, dy: 35))

            // Name banner at top
            let bannerRect = CGRect(x: 40, y: 50, width: size.width - 80, height: 70)
            ctx.setFillColor(UIColor.black.withAlphaComponent(0.4).cgColor)
            ctx.fill(bannerRect)

            // Character name
            let nameAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 48),
                .foregroundColor: UIColor.white
            ]
            let name = card.name.uppercased()
            let nameSize = name.size(withAttributes: nameAttrs)
            name.draw(at: CGPoint(x: (size.width - nameSize.width) / 2, y: 60), withAttributes: nameAttrs)

            // Central artwork area
            let artRect = CGRect(x: 60, y: 140, width: size.width - 120, height: 400)
            ctx.setFillColor(UIColor.black.withAlphaComponent(0.3).cgColor)
            ctx.fill(artRect)

            // Character emoji/symbol in center
            let emoji: String
            switch card.creatureId {
            case "charizard": emoji = "🐉"
            case "messi": emoji = "⚽"
            default: emoji = "✨"
            }

            let emojiAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 180)
            ]
            let emojiSize = emoji.size(withAttributes: emojiAttrs)
            emoji.draw(at: CGPoint(x: (size.width - emojiSize.width) / 2, y: 240), withAttributes: emojiAttrs)

            // Stats area
            let statsRect = CGRect(x: 60, y: 560, width: size.width - 120, height: 120)
            ctx.setFillColor(UIColor.black.withAlphaComponent(0.4).cgColor)
            ctx.fill(statsRect)

            // Element and rarity
            let infoAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 32),
                .foregroundColor: UIColor.white
            ]
            let elementText = "⚡ \(card.element)"
            elementText.draw(at: CGPoint(x: 80, y: 580), withAttributes: infoAttrs)

            let rarityText = "★ \(card.rarity.rawValue)"
            rarityText.draw(at: CGPoint(x: 80, y: 630), withAttributes: infoAttrs)

            // HP or stats on right
            let hpAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 40),
                .foregroundColor: UIColor.yellow
            ]
            let hpText = card.creatureId == "messi" ? "⚽ 10" : "HP 120"
            let hpSize = hpText.size(withAttributes: hpAttrs)
            hpText.draw(at: CGPoint(x: size.width - 80 - hpSize.width, y: 600), withAttributes: hpAttrs)

            // Description at bottom
            let descAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24),
                .foregroundColor: UIColor.white.withAlphaComponent(0.9)
            ]
            let descRect = CGRect(x: 60, y: 700, width: size.width - 120, height: 150)
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            let descAttrsFull: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24),
                .foregroundColor: UIColor.white.withAlphaComponent(0.9),
                .paragraphStyle: paragraphStyle
            ]
            (card.description as NSString).draw(in: descRect, withAttributes: descAttrsFull)
        }
    }

    /// Create the back of the trading card
    private func createCardBack(for card: CollectibleCard) -> UIImage {
        let size = CGSize(width: 630, height: 880)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { context in
            let ctx = context.cgContext
            let rect = CGRect(origin: .zero, size: size)

            // Dark blue/purple gradient background
            let colors = [
                UIColor(red: 0.1, green: 0.1, blue: 0.3, alpha: 1).cgColor,
                UIColor(red: 0.15, green: 0.1, blue: 0.4, alpha: 1).cgColor,
                UIColor(red: 0.1, green: 0.05, blue: 0.25, alpha: 1).cgColor
            ]
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: nil)!
            ctx.drawRadialGradient(gradient, startCenter: CGPoint(x: size.width/2, y: size.height/2), startRadius: 0, endCenter: CGPoint(x: size.width/2, y: size.height/2), endRadius: size.width, options: [])

            // Pattern of circles
            ctx.setFillColor(UIColor.white.withAlphaComponent(0.05).cgColor)
            for row in 0..<12 {
                for col in 0..<8 {
                    let x = CGFloat(col) * 80 + 35
                    let y = CGFloat(row) * 80 + 40
                    ctx.fillEllipse(in: CGRect(x: x, y: y, width: 40, height: 40))
                }
            }

            // Border
            ctx.setStrokeColor(UIColor.white.withAlphaComponent(0.3).cgColor)
            ctx.setLineWidth(8)
            ctx.stroke(rect.insetBy(dx: 20, dy: 20))

            // Center logo area
            let logoRect = CGRect(x: size.width/2 - 150, y: size.height/2 - 150, width: 300, height: 300)
            ctx.setFillColor(UIColor.white.withAlphaComponent(0.1).cgColor)
            ctx.fillEllipse(in: logoRect)

            // "CollectARble" text
            let logoAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 42),
                .foregroundColor: UIColor.white
            ]
            let logoText = "CollectARble"
            let logoSize = logoText.size(withAttributes: logoAttrs)
            logoText.draw(at: CGPoint(x: (size.width - logoSize.width) / 2, y: size.height/2 - 25), withAttributes: logoAttrs)

            // AR icon
            let arAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 60)
            ]
            let arIcon = "📱"
            let arSize = arIcon.size(withAttributes: arAttrs)
            arIcon.draw(at: CGPoint(x: (size.width - arSize.width) / 2, y: size.height/2 + 40), withAttributes: arAttrs)
        }
    }
}

// MARK: - Card Detail View

struct CardDetailView: View {
    let card: CollectibleCard
    @Binding var showARExperience: Bool
    @Binding var selectedCreatureId: String
    @Environment(\.dismiss) private var dismiss
    @State private var rotation: Double = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Large 3D card view
                SceneKitCardView(card: card, rotation: $rotation)
                    .frame(height: 350)
                    .clipShape(.rect(cornerRadius: 16))
                    .shadow(color: card.displayColor.opacity(0.5), radius: 20, y: 10)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                rotation += value.translation.width * 0.3
                            }
                    )

                // Card info
                VStack(spacing: 12) {
                    Text(card.name)
                        .font(.title.bold())

                    HStack(spacing: 16) {
                        Label(card.element, systemImage: card.elementSymbol)
                            .foregroundStyle(card.displayColor)

                        Label(card.rarity.rawValue, systemImage: "star.fill")
                            .foregroundStyle(.yellow)

                        if card.isHolographic {
                            Label("Holo", systemImage: "sparkles")
                                .foregroundStyle(.purple)
                        }
                    }
                    .font(.subheadline)

                    Text(card.description)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer()

                // Throw to summon button
                Button {
                    selectedCreatureId = card.creatureId
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showARExperience = true
                    }
                } label: {
                    HStack {
                        Image(systemName: card.creatureId == "messi" ? "soccerball" : "circle.fill")
                            .foregroundStyle(card.creatureId == "messi" ? .white : .red)
                        Text("Throw to Summon")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(card.displayColor, in: .rect(cornerRadius: 16))
                }
                .padding(.horizontal)
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }
}

// MARK: - Data Models

struct CollectibleCard: Identifiable {
    let id = UUID()
    let name: String
    let element: String
    let elementSymbol: String
    let elementColor: UIColor
    let rarity: Rarity
    let isHolographic: Bool
    let description: String
    let imageName: String
    let creatureId: String

    /// SwiftUI Color for use in views
    var displayColor: Color {
        Color(elementColor)
    }

    enum Rarity: String {
        case common = "Common"
        case uncommon = "Uncommon"
        case rare = "Rare"
        case ultraRare = "Ultra Rare"
        case legendary = "Legendary"
    }

    static let sampleCards: [CollectibleCard] = [
        CollectibleCard(
            name: "Charizard",
            element: "Fire",
            elementSymbol: "flame.fill",
            elementColor: UIColor(red: 1, green: 0.4, blue: 0.1, alpha: 1),
            rarity: .legendary,
            isHolographic: true,
            description: "A Fire/Flying-type Pokemon. The flame on its tail indicates its life force.",
            imageName: "charizard_holographic",
            creatureId: "charizard"
        ),
        CollectibleCard(
            name: "Lionel Messi",
            element: "Sports",
            elementSymbol: "sportscourt.fill",
            elementColor: UIColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1),
            rarity: .legendary,
            isHolographic: true,
            description: "The greatest footballer of all time. 8 Ballon d'Or winner and World Cup champion.",
            imageName: "messi_card",
            creatureId: "messi"
        )
    ]
}

#Preview {
    CardCollectionView()
}
