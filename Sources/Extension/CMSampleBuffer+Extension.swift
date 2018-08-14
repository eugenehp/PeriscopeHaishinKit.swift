import CoreMedia

extension CMSampleBuffer {
    var dependsOnOthers: Bool {
        guard
            let attachments = CMSampleBufferGetSampleAttachmentsArray(self, false) else {
                return false
        }
        let attachment: [NSObject: AnyObject] = unsafeBitCast(CFArrayGetValueAtIndex(attachments, 0), to: CFDictionary.self) as [NSObject: AnyObject]
        return attachment["DependsOnOthers" as NSObject] as! Bool
    }
    var dataBuffer: CMBlockBuffer? {
        get {
            return CMSampleBufferGetDataBuffer(self)
        }
        set {
            _ = newValue.map {
                CMSampleBufferSetDataBuffer(self, $0)
            }
        }
    }
    var imageBuffer: CVImageBuffer? {
        return CMSampleBufferGetImageBuffer(self)
    }
    var numSamples: CMItemCount {
        return CMSampleBufferGetNumSamples(self)
    }
    var duration: CMTime {
        return CMSampleBufferGetDuration(self)
    }
    var formatDescription: CMFormatDescription? {
        return CMSampleBufferGetFormatDescription(self)
    }
    var decodeTimeStamp: CMTime {
        return CMSampleBufferGetDecodeTimeStamp(self)
    }
    var presentationTimeStamp: CMTime {
        return CMSampleBufferGetPresentationTimeStamp(self)
    }
    var sampleTimingInfo: [CMSampleTimingInfo] {
        var count: CMItemCount = 0
        CMSampleBufferGetSampleTimingInfoArray(self, 0, nil, &count)
        var result = [CMSampleTimingInfo](repeating: CMSampleTimingInfo(duration: kCMTimeZero,
                                                                      presentationTimeStamp: kCMTimeZero,
                                                                      decodeTimeStamp: kCMTimeZero),
                                          count: count)
        CMSampleBufferGetSampleTimingInfoArray(self, count, &result, &count)
        return result
    }
}
