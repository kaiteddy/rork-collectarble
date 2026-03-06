import ARKit
import UIKit

struct CardReferenceService {
    static func generateReferenceImages() -> Set<ARReferenceImage> {
        var images = Set<ARReferenceImage>()
        let cardPhysicalWidth: CGFloat = 0.063
        
        for creature in Creature.allCreatures {
            guard let cardImage = renderCardImage(for: creature) else { continue }
            guard let cgImage = cardImage.cgImage else { continue }
            
            let referenceImage = ARReferenceImage(cgImage, orientation: .up, physicalWidth: cardPhysicalWidth)
            referenceImage.name = creature.id
            images.insert(referenceImage)
        }
        
        return images
    }
    
    static func renderCardImage(for creature: Creature) -> UIImage? {
        let size = CGSize(width: 300, height: 420)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            let ctx = context.cgContext
            let rect = CGRect(origin: .zero, size: size)
            
            let bgColors: [CGColor]
            switch creature.element {
            case .fire:
                bgColors = [
                    UIColor(red: 0.15, green: 0.05, blue: 0.02, alpha: 1).cgColor,
                    UIColor(red: 0.6, green: 0.15, blue: 0.05, alpha: 1).cgColor,
                    UIColor(red: 1.0, green: 0.4, blue: 0.1, alpha: 1).cgColor
                ]
            case .ice:
                bgColors = [
                    UIColor(red: 0.02, green: 0.05, blue: 0.2, alpha: 1).cgColor,
                    UIColor(red: 0.1, green: 0.3, blue: 0.7, alpha: 1).cgColor,
                    UIColor(red: 0.5, green: 0.8, blue: 1.0, alpha: 1).cgColor
                ]
            case .nature:
                bgColors = [
                    UIColor(red: 0.02, green: 0.12, blue: 0.02, alpha: 1).cgColor,
                    UIColor(red: 0.1, green: 0.5, blue: 0.15, alpha: 1).cgColor,
                    UIColor(red: 0.3, green: 0.9, blue: 0.4, alpha: 1).cgColor
                ]
            }
            
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: bgColors as CFArray,
                locations: [0, 0.5, 1]
            )!
            ctx.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])
            
            let borderRect = rect.insetBy(dx: 8, dy: 8)
            ctx.setStrokeColor(UIColor.white.withAlphaComponent(0.6).cgColor)
            ctx.setLineWidth(3)
            let borderPath = UIBezierPath(roundedRect: borderRect, cornerRadius: 16)
            ctx.addPath(borderPath.cgPath)
            ctx.strokePath()
            
            let innerRect = rect.insetBy(dx: 16, dy: 16)
            ctx.setStrokeColor(UIColor.white.withAlphaComponent(0.25).cgColor)
            ctx.setLineWidth(1.5)
            let innerPath = UIBezierPath(roundedRect: innerRect, cornerRadius: 12)
            ctx.addPath(innerPath.cgPath)
            ctx.strokePath()
            
            drawCreatureArt(ctx: ctx, creature: creature, in: CGRect(x: 30, y: 70, width: 240, height: 200))
            
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 28, weight: .heavy),
                .foregroundColor: UIColor.white
            ]
            let title = creature.name.uppercased()
            let titleSize = title.size(withAttributes: titleAttrs)
            title.draw(at: CGPoint(x: (size.width - titleSize.width) / 2, y: 24), withAttributes: titleAttrs)
            
            let hpAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16, weight: .bold),
                .foregroundColor: UIColor.white.withAlphaComponent(0.9)
            ]
            let hp: String
            switch creature.element {
            case .fire: hp = "HP 120"
            case .ice: hp = "HP 100"
            case .nature: hp = "HP 90"
            }
            hp.draw(at: CGPoint(x: size.width - 80, y: 28), withAttributes: hpAttrs)
            
            let attackBg = CGRect(x: 20, y: 290, width: size.width - 40, height: 50)
            ctx.setFillColor(UIColor.black.withAlphaComponent(0.35).cgColor)
            let attackPath = UIBezierPath(roundedRect: attackBg, cornerRadius: 8)
            ctx.addPath(attackPath.cgPath)
            ctx.fillPath()
            
            let attackAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 20, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            let attackText = creature.attackName
            let attackSize = attackText.size(withAttributes: attackAttrs)
            attackText.draw(
                at: CGPoint(x: (size.width - attackSize.width) / 2, y: attackBg.midY - attackSize.height / 2),
                withAttributes: attackAttrs
            )
            
            drawDecorativeElements(ctx: ctx, creature: creature, size: size)
            
            let idAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 10, weight: .medium),
                .foregroundColor: UIColor.white.withAlphaComponent(0.5)
            ]
            let idText = "CollectARble #\(creature.id.hashValue & 0xFFFF)"
            idText.draw(at: CGPoint(x: 20, y: size.height - 30), withAttributes: idAttrs)
        }
    }
    
    private static func drawCreatureArt(ctx: CGContext, creature: Creature, in rect: CGRect) {
        ctx.saveGState()
        
        let centerX = rect.midX
        let centerY = rect.midY
        
        switch creature.element {
        case .fire:
            for i in 0..<12 {
                let angle = CGFloat(i) / 12.0 * .pi * 2
                let radius: CGFloat = 60 + CGFloat(i % 3) * 15
                let x = centerX + cos(angle) * radius * 0.6
                let y = centerY + sin(angle) * radius * 0.8
                let flameSize = CGFloat(8 + (i % 4) * 6)
                
                ctx.setFillColor(UIColor(red: 1, green: CGFloat(0.3 + Double(i % 5) * 0.1), blue: 0.1, alpha: 0.8).cgColor)
                ctx.fillEllipse(in: CGRect(x: x - flameSize/2, y: y - flameSize, width: flameSize, height: flameSize * 1.5))
            }
            
            ctx.setFillColor(UIColor(red: 1, green: 0.6, blue: 0.1, alpha: 0.9).cgColor)
            let bodyPath = UIBezierPath()
            bodyPath.move(to: CGPoint(x: centerX, y: centerY - 50))
            bodyPath.addCurve(to: CGPoint(x: centerX + 45, y: centerY + 30), controlPoint1: CGPoint(x: centerX + 60, y: centerY - 40), controlPoint2: CGPoint(x: centerX + 55, y: centerY + 10))
            bodyPath.addCurve(to: CGPoint(x: centerX, y: centerY + 50), controlPoint1: CGPoint(x: centerX + 35, y: centerY + 50), controlPoint2: CGPoint(x: centerX + 10, y: centerY + 55))
            bodyPath.addCurve(to: CGPoint(x: centerX - 45, y: centerY + 30), controlPoint1: CGPoint(x: centerX - 10, y: centerY + 55), controlPoint2: CGPoint(x: centerX - 35, y: centerY + 50))
            bodyPath.addCurve(to: CGPoint(x: centerX, y: centerY - 50), controlPoint1: CGPoint(x: centerX - 55, y: centerY + 10), controlPoint2: CGPoint(x: centerX - 60, y: centerY - 40))
            bodyPath.close()
            ctx.addPath(bodyPath.cgPath)
            ctx.fillPath()
            
            ctx.setFillColor(UIColor.white.withAlphaComponent(0.9).cgColor)
            ctx.fillEllipse(in: CGRect(x: centerX - 20, y: centerY - 25, width: 12, height: 14))
            ctx.fillEllipse(in: CGRect(x: centerX + 8, y: centerY - 25, width: 12, height: 14))
            ctx.setFillColor(UIColor.black.cgColor)
            ctx.fillEllipse(in: CGRect(x: centerX - 16, y: centerY - 21, width: 6, height: 8))
            ctx.fillEllipse(in: CGRect(x: centerX + 12, y: centerY - 21, width: 6, height: 8))
            
        case .ice:
            for i in 0..<6 {
                let angle = CGFloat(i) / 6.0 * .pi * 2
                let innerR: CGFloat = 25
                let outerR: CGFloat = 70
                
                ctx.setStrokeColor(UIColor(red: 0.7, green: 0.9, blue: 1.0, alpha: 0.7).cgColor)
                ctx.setLineWidth(3)
                ctx.move(to: CGPoint(x: centerX + cos(angle) * innerR, y: centerY + sin(angle) * innerR))
                ctx.addLine(to: CGPoint(x: centerX + cos(angle) * outerR, y: centerY + sin(angle) * outerR))
                ctx.strokePath()
                
                let branchAngle1 = angle + 0.3
                let branchAngle2 = angle - 0.3
                let branchStart: CGFloat = 40
                let branchEnd: CGFloat = 55
                ctx.move(to: CGPoint(x: centerX + cos(angle) * branchStart, y: centerY + sin(angle) * branchStart))
                ctx.addLine(to: CGPoint(x: centerX + cos(branchAngle1) * branchEnd, y: centerY + sin(branchAngle1) * branchEnd))
                ctx.strokePath()
                ctx.move(to: CGPoint(x: centerX + cos(angle) * branchStart, y: centerY + sin(angle) * branchStart))
                ctx.addLine(to: CGPoint(x: centerX + cos(branchAngle2) * branchEnd, y: centerY + sin(branchAngle2) * branchEnd))
                ctx.strokePath()
            }
            
            ctx.setFillColor(UIColor(red: 0.6, green: 0.85, blue: 1.0, alpha: 0.9).cgColor)
            let crystalPath = UIBezierPath()
            crystalPath.move(to: CGPoint(x: centerX, y: centerY - 35))
            crystalPath.addLine(to: CGPoint(x: centerX + 25, y: centerY))
            crystalPath.addLine(to: CGPoint(x: centerX + 15, y: centerY + 30))
            crystalPath.addLine(to: CGPoint(x: centerX - 15, y: centerY + 30))
            crystalPath.addLine(to: CGPoint(x: centerX - 25, y: centerY))
            crystalPath.close()
            ctx.addPath(crystalPath.cgPath)
            ctx.fillPath()
            
            ctx.setFillColor(UIColor.white.withAlphaComponent(0.95).cgColor)
            ctx.fillEllipse(in: CGRect(x: centerX - 14, y: centerY - 12, width: 10, height: 12))
            ctx.fillEllipse(in: CGRect(x: centerX + 4, y: centerY - 12, width: 10, height: 12))
            ctx.setFillColor(UIColor(red: 0.1, green: 0.2, blue: 0.5, alpha: 1).cgColor)
            ctx.fillEllipse(in: CGRect(x: centerX - 11, y: centerY - 8, width: 5, height: 7))
            ctx.fillEllipse(in: CGRect(x: centerX + 7, y: centerY - 8, width: 5, height: 7))
            
        case .nature:
            ctx.setFillColor(UIColor(red: 0.35, green: 0.22, blue: 0.1, alpha: 1).cgColor)
            ctx.fill(CGRect(x: centerX - 10, y: centerY - 10, width: 20, height: 60))
            
            for i in 0..<8 {
                let leafAngle = CGFloat(i) / 8.0 * .pi * 2
                let leafDist: CGFloat = 35 + CGFloat(i % 3) * 10
                let leafX = centerX + cos(leafAngle) * leafDist
                let leafY = centerY - 20 + sin(leafAngle) * leafDist * 0.7
                let leafW: CGFloat = CGFloat(18 + (i % 3) * 8)
                let leafH: CGFloat = CGFloat(12 + (i % 2) * 6)
                
                ctx.saveGState()
                ctx.translateBy(x: leafX, y: leafY)
                ctx.rotate(by: leafAngle)
                ctx.setFillColor(UIColor(red: CGFloat(0.1 + Double(i % 3) * 0.1), green: CGFloat(0.6 + Double(i % 4) * 0.08), blue: 0.2, alpha: 0.85).cgColor)
                ctx.fillEllipse(in: CGRect(x: -leafW/2, y: -leafH/2, width: leafW, height: leafH))
                ctx.restoreGState()
            }
            
            ctx.setFillColor(UIColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 0.95).cgColor)
            ctx.fillEllipse(in: CGRect(x: centerX - 30, y: centerY - 45, width: 60, height: 50))
            
            ctx.setFillColor(UIColor.white.withAlphaComponent(0.9).cgColor)
            ctx.fillEllipse(in: CGRect(x: centerX - 15, y: centerY - 30, width: 11, height: 13))
            ctx.fillEllipse(in: CGRect(x: centerX + 4, y: centerY - 30, width: 11, height: 13))
            ctx.setFillColor(UIColor(red: 0.05, green: 0.3, blue: 0.1, alpha: 1).cgColor)
            ctx.fillEllipse(in: CGRect(x: centerX - 12, y: centerY - 26, width: 6, height: 7))
            ctx.fillEllipse(in: CGRect(x: centerX + 7, y: centerY - 26, width: 6, height: 7))
        }
        
        ctx.restoreGState()
    }
    
    private static func drawDecorativeElements(ctx: CGContext, creature: Creature, size: CGSize) {
        let elementColor: UIColor
        switch creature.element {
        case .fire: elementColor = UIColor(red: 1, green: 0.8, blue: 0.3, alpha: 0.4)
        case .ice: elementColor = UIColor(red: 0.7, green: 0.9, blue: 1.0, alpha: 0.4)
        case .nature: elementColor = UIColor(red: 0.5, green: 1.0, blue: 0.5, alpha: 0.4)
        }
        
        ctx.setFillColor(elementColor.cgColor)
        
        let positions: [(CGFloat, CGFloat, CGFloat)] = [
            (25, 360, 4), (50, 375, 3), (80, 355, 5),
            (200, 365, 3.5), (240, 380, 4.5), (260, 350, 3),
            (140, 370, 2.5), (170, 385, 3)
        ]
        
        for (x, y, r) in positions {
            ctx.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
        }
    }
}
