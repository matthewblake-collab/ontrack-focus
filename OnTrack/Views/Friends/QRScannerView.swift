import SwiftUI
import AVFoundation

// MARK: - QR Scanner Sheet

struct QRScannerSheet: View {
    let onScan: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var hasCameraPermission: Bool? = nil
    @State private var didScan = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if hasCameraPermission == true {
                QRScannerRepresentable { code in
                    guard !didScan else { return }
                    didScan = true
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        onScan(code)
                    }
                }
                .ignoresSafeArea()

                VStack {
                    HStack {
                        Spacer()
                        Button("Cancel") { dismiss() }
                            .foregroundColor(.white)
                            .fontWeight(.semibold)
                            .padding()
                    }
                    Spacer()
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.white, lineWidth: 3)
                            .frame(width: 240, height: 240)
                        ForEach([(-1, -1), (1, -1), (-1, 1), (1, 1)].indices, id: \.self) { i in
                            let corners = [(-1, -1), (1, -1), (-1, 1), (1, 1)]
                            let (hx, hy) = corners[i]
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(red: 0.08, green: 0.75, blue: 0.45))
                                .frame(width: 24, height: 24)
                                .offset(x: CGFloat(hx) * 108, y: CGFloat(hy) * 108)
                        }
                    }
                    Spacer()
                    Text("Point camera at a friend's QR code")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.bottom, 52)
                }

            } else if hasCameraPermission == false {
                VStack(spacing: 16) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.white.opacity(0.4))
                    Text("Camera access required")
                        .font(.headline).foregroundColor(.white)
                    Text("Enable camera access in Settings to scan friend codes.")
                        .font(.caption).foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .foregroundColor(Color(red: 0.08, green: 0.55, blue: 0.38))
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.top, 4)
                }
                .padding(32)
            } else {
                ProgressView().tint(.white)
            }
        }
        .task {
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                hasCameraPermission = true
            case .notDetermined:
                hasCameraPermission = await AVCaptureDevice.requestAccess(for: .video)
            default:
                hasCameraPermission = false
            }
        }
    }
}

// MARK: - UIViewControllerRepresentable

struct QRScannerRepresentable: UIViewControllerRepresentable {
    let onScan: (String) -> Void
    func makeUIViewController(context: Context) -> QRScannerViewController {
        let vc = QRScannerViewController()
        vc.onScan = onScan
        return vc
    }
    func updateUIViewController(_ vc: QRScannerViewController, context: Context) {}
}

class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onScan: ((String) -> Void)?
    private let session = AVCaptureSession()
    private var preview: AVCaptureVideoPreviewLayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else { return }
        let output = AVCaptureMetadataOutput()
        session.addInput(input)
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        view.layer.insertSublayer(layer, at: 0)
        self.preview = layer
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        preview?.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { self.session.startRunning() }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if session.isRunning { session.stopRunning() }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput objects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        if let obj = objects.first as? AVMetadataMachineReadableCodeObject,
           let code = obj.stringValue {
            onScan?(code)
        }
    }
}
