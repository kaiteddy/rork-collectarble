import Vision
import ARKit
import CoreImage

class CardDetectionService {
    private var lastDetectionTime: TimeInterval = 0
    private let detectionInterval: TimeInterval = 0.25
    private var isProcessing: Bool = false
    private var consecutiveDetections: Int = 0
    private let requiredConsecutive: Int = 2

    struct DetectedCard {
        let boundingBox: CGRect
        let screenCenter: CGPoint
        let confidence: Float
    }

    func detectCard(in frame: ARFrame, viewportSize: CGSize) -> DetectedCard? {
        let now = frame.timestamp
        guard now - lastDetectionTime >= detectionInterval, !isProcessing else { return nil }

        isProcessing = true
        lastDetectionTime = now

        let pixelBuffer = frame.capturedImage

        let request = VNDetectRectanglesRequest()
        request.minimumAspectRatio = 0.4
        request.maximumAspectRatio = 0.95
        request.minimumSize = 0.05
        request.minimumConfidence = 0.5
        request.maximumObservations = 3

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])

        do {
            try handler.perform([request])
        } catch {
            isProcessing = false
            consecutiveDetections = 0
            return nil
        }

        isProcessing = false

        guard let results = request.results, !results.isEmpty else {
            consecutiveDetections = 0
            return nil
        }

        let best = results.max(by: { $0.confidence < $1.confidence })!

        let box = best.boundingBox

        let area = box.width * box.height
        guard area > 0.01 else {
            consecutiveDetections = 0
            return nil
        }

        consecutiveDetections += 1

        guard consecutiveDetections >= requiredConsecutive else {
            return nil
        }

        let centerX = box.midX * viewportSize.width
        let centerY = (1 - box.midY) * viewportSize.height

        return DetectedCard(
            boundingBox: box,
            screenCenter: CGPoint(x: centerX, y: centerY),
            confidence: best.confidence
        )
    }

    func reset() {
        lastDetectionTime = 0
        isProcessing = false
        consecutiveDetections = 0
    }
}
