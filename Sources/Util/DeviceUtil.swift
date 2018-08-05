import AVFoundation

#if os(iOS) || os(macOS)
extension AVFrameRateRange {
    func clamp(rate: Float64) -> Float64 {
        return max(minFrameRate, min(maxFrameRate, rate))
    }

    func contains(rate: Float64) -> Bool {
        return (minFrameRate...maxFrameRate) ~= rate
    }
}

extension AVCaptureDevice {
    func actualFPS(_ fps: Float64) -> (fps: Float64, duration: CMTime)? {
        var durations: [CMTime] = []
        var frameRates: [Float64] = []

        for range in activeFormat.videoSupportedFrameRateRanges {
            if range.minFrameRate == range.maxFrameRate {
                durations.append(range.minFrameDuration)
                frameRates.append(range.maxFrameRate)
                continue
            }

            if range.contains(rate: fps) {
                return (fps, CMTimeMake(100, Int32(100 * fps)))
            }

            let actualFPS: Float64 = range.clamp(rate: fps)
            return (actualFPS, CMTimeMake(100, Int32(100 * actualFPS)))
        }

        let diff = frameRates.map { abs($0 - fps) }

        if let minElement: Float64 = diff.min() {
            for i in 0..<diff.count where diff[i] == minElement {
                return (frameRates[i], durations[i])
            }
        }

        return nil
    }
}

public final class DeviceUtil {
    private init() {
    }

    static public func device(withPosition: AVCaptureDevice.Position) -> AVCaptureDevice? {
        return AVCaptureDevice.devices().first {
            $0.hasMediaType(.video) && $0.position == withPosition
        }
    }

    static public func device(withLocalizedName: String, mediaType: AVMediaType) -> AVCaptureDevice? {
        return AVCaptureDevice.devices().first {
            $0.hasMediaType(mediaType) && $0.localizedName == withLocalizedName
        }
    }
}
#endif
