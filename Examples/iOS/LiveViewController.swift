import HaishinKit
import UIKit
import AVFoundation
import Photos
import VideoToolbox

let sampleRate: Double = 44_100

class ExampleRecorderDelegate: DefaultAVMixerRecorderDelegate {
    override func didFinishWriting(_ recorder: AVMixerRecorder) {
        guard let writer: AVAssetWriter = recorder.writer else { return }
        PHPhotoLibrary.shared().performChanges({() -> Void in
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: writer.outputURL)
        }, completionHandler: { (_, error) -> Void in
            do {
                try FileManager.default.removeItem(at: writer.outputURL)
            } catch let error {
                print(error)
            }
        })
    }
}

final class LiveViewController: UIViewController {
    var rtmpConnection: RTMPConnection = RTMPConnection()
    var rtmpStream: RTMPStream!
    var sharedObject: RTMPSharedObject!
    var currentEffect: VisualEffect?

    @IBOutlet var lfView: GLHKView?
    @IBOutlet var currentFPSLabel: UILabel?
    @IBOutlet var publishButton: UIButton?
    @IBOutlet var pauseButton: UIButton?
    @IBOutlet var videoBitrateLabel: UILabel?
    @IBOutlet var videoBitrateSlider: UISlider?
    @IBOutlet var audioBitrateLabel: UILabel?
    @IBOutlet var zoomSlider: UISlider?
    @IBOutlet var audioBitrateSlider: UISlider?
    @IBOutlet var fpsControl: UISegmentedControl?
    @IBOutlet var effectSegmentControl: UISegmentedControl?

    var currentPosition: AVCaptureDevice.Position = .back

    override func viewDidLoad() {
        super.viewDidLoad()

        rtmpConnection.flashVer = "Argon"

        rtmpStream = RTMPStream(connection: rtmpConnection)
        rtmpStream.syncOrientation = true
        rtmpStream.captureSettings = [
            "sessionPreset": AVCaptureSession.Preset.hd1280x720.rawValue,
            "continuousAutofocus": true,
            "continuousExposure": true
        ]
        rtmpStream.videoSettings = [
            "width": 1280,
            "height": 720,
            "profileLevel": kVTProfileLevel_H264_Baseline_3_1,
            "maxKeyFrameIntervalDuration": 3,
            //
            "bitrate": 300 * 1024
        ]
        rtmpStream.audioSettings = [
            "muted": true,
            //
            "sampleRate": sampleRate
        ]
        rtmpStream.mixer.recorder.delegate = ExampleRecorderDelegate()

        videoBitrateSlider?.value = Float(RTMPStream.defaultVideoBitrate) / 1024
        audioBitrateSlider?.value = Float(RTMPStream.defaultAudioBitrate) / 1024
    }

    override func viewWillAppear(_ animated: Bool) {
        logger.info("viewWillAppear")
        super.viewWillAppear(animated)
        rtmpStream.attachAudio(AVCaptureDevice.default(for: .audio)) { error in
            logger.warn(error.description)
        }
        rtmpStream.attachCamera(DeviceUtil.device(withPosition: currentPosition)) { error in
            logger.warn(error.description)
        }
        rtmpStream.addObserver(self, forKeyPath: "currentFPS", options: .new, context: nil)
        lfView?.attachStream(rtmpStream)
    }

    override func viewWillDisappear(_ animated: Bool) {
        logger.info("viewWillDisappear")
        super.viewWillDisappear(animated)
        rtmpStream.removeObserver(self, forKeyPath: "currentFPS")
        rtmpStream.close()
        rtmpStream.dispose()
    }

    @IBAction func rotateCamera(_ sender: UIButton) {
        logger.info("rotateCamera")
        let position: AVCaptureDevice.Position = currentPosition == .back ? .front : .back
        rtmpStream.attachCamera(DeviceUtil.device(withPosition: position)) { error in
            logger.warn(error.description)
        }
        currentPosition = position
    }

    @IBAction func toggleTorch(_ sender: UIButton) {
        rtmpStream.torch = !rtmpStream.torch
    }

    @IBAction func on(slider: UISlider) {
        if slider == audioBitrateSlider {
            audioBitrateLabel?.text = "audio \(Int(slider.value))/kbps"
            rtmpStream.audioSettings["bitrate"] = slider.value * 1024
        }
        if slider == videoBitrateSlider {
            videoBitrateLabel?.text = "video \(Int(slider.value))/kbps"
            rtmpStream.videoSettings["bitrate"] = slider.value * 1024
        }
        if slider == zoomSlider {
            rtmpStream.setZoomFactor(CGFloat(slider.value), ramping: true, withRate: 5.0)
        }
    }

    @IBAction func on(pause: UIButton) {
        rtmpStream.togglePause()
    }

    @IBAction func on(close: UIButton) {
        self.dismiss(animated: true, completion: nil)
    }

    @IBAction func on(publish: UIButton) {
        if publish.isSelected {
            UIApplication.shared.isIdleTimerDisabled = false
            rtmpConnection.close()
            rtmpConnection.removeEventListener(Event.RTMP_STATUS, selector: #selector(rtmpStatusHandler), observer: self)
            publish.setTitle("●", for: [])
        } else {
            UIApplication.shared.isIdleTimerDisabled = true
            rtmpConnection.addEventListener(Event.RTMP_STATUS, selector: #selector(rtmpStatusHandler), observer: self)
            rtmpConnection.connect(Preference.defaultInstance.uri!)
            publish.setTitle("■", for: [])
        }
        publish.isSelected = !publish.isSelected
    }

    @objc func rtmpStatusHandler(_ notification: Notification) {
        let e: Event = Event.from(notification)
        if let data: ASObject = e.data as? ASObject, let code: String = data["code"] as? String {
            switch code {
            case RTMPConnection.Code.connectSuccess.rawValue:
                rtmpStream!.publish(Preference.defaultInstance.streamName!)
                // sharedObject!.connect(rtmpConnection)
            default:
                break
            }
        }
    }

    func tapScreen(_ gesture: UIGestureRecognizer) {
        if let gestureView = gesture.view, gesture.state == .ended {
            let touchPoint: CGPoint = gesture.location(in: gestureView)
            let pointOfInterest: CGPoint = CGPoint(x: touchPoint.x/gestureView.bounds.size.width,
                y: touchPoint.y/gestureView.bounds.size.height)
            print("pointOfInterest: \(pointOfInterest)")
            rtmpStream.setPointOfInterest(pointOfInterest, exposure: pointOfInterest)
        }
    }

    @IBAction func onFPSValueChanged(_ segment: UISegmentedControl) {
        switch segment.selectedSegmentIndex {
        case 0:
            rtmpStream.captureSettings["fps"] = 15.0
        case 1:
            rtmpStream.captureSettings["fps"] = 30.0
        case 2:
            rtmpStream.captureSettings["fps"] = 60.0
        default:
            break
        }
    }

    @IBAction func onEffectValueChanged(_ segment: UISegmentedControl) {
        if let currentEffect: VisualEffect = currentEffect {
            _ = rtmpStream.unregisterEffect(video: currentEffect)
        }
        switch segment.selectedSegmentIndex {
        case 1:
            currentEffect = MonochromeEffect()
            _ = rtmpStream.registerEffect(video: currentEffect!)
        case 2:
            currentEffect = PronamaEffect()
            _ = rtmpStream.registerEffect(video: currentEffect!)
        default:
            break
        }
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        if Thread.isMainThread {
            currentFPSLabel?.text = "\(rtmpStream.currentFPS)"
        }
    }
}
