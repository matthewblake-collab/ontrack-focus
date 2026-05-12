import SwiftUI
import AVFoundation
import VisionKit
import Vision

// MARK: - Barcode Scanner Sheet
//
// Camera-driven product-barcode scanner used by AddSupplementView. Wraps
// VisionKit's DataScannerViewController (iOS 16+ — the app targets 17.6, so it's
// always available API-wise; runtime availability is gated below). Mirrors the
// dark visual style of QRScannerSheet.

struct BarcodeScannerSheet: View {
    let onScan: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var hasCameraPermission: Bool? = nil
    @State private var didScan = false

    private var scannerSupported: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if hasCameraPermission == true && scannerSupported {
                BarcodeScannerRepresentable { code in
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
                            .frame(width: 280, height: 160)
                        ForEach([(-1, -1), (1, -1), (-1, 1), (1, 1)].indices, id: \.self) { i in
                            let corners = [(-1, -1), (1, -1), (-1, 1), (1, 1)]
                            let (hx, hy) = corners[i]
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(red: 0.08, green: 0.75, blue: 0.45))
                                .frame(width: 24, height: 24)
                                .offset(x: CGFloat(hx) * 128, y: CGFloat(hy) * 68)
                        }
                    }
                    Spacer()
                    Text("Point the camera at a product barcode")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.bottom, 52)
                }

            } else if hasCameraPermission == false {
                permissionDeniedView
            } else if hasCameraPermission == true && !scannerSupported {
                unavailableView
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

    private var permissionDeniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.4))
            Text("Camera access required")
                .font(.headline).foregroundColor(.white)
            Text("Enable camera access in Settings to scan supplement barcodes.")
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
    }

    private var unavailableView: some View {
        VStack(spacing: 16) {
            Image(systemName: "barcode.viewfinder")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.4))
            Text("Scanning needs a real device")
                .font(.headline).foregroundColor(.white)
            Text("Barcode scanning isn't available on the Simulator or this hardware. Enter the supplement details manually instead.")
                .font(.caption).foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
            Button("Cancel") { dismiss() }
                .foregroundColor(.white.opacity(0.5))
                .padding(.top, 4)
        }
        .padding(32)
    }
}

// MARK: - UIViewControllerRepresentable

struct BarcodeScannerRepresentable: UIViewControllerRepresentable {
    let onScan: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onScan: onScan) }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let types: Set<DataScannerViewController.RecognizedDataType> = [
            .barcode(symbologies: [.ean13, .ean8, .upce, .code128])
        ]
        let scanner = DataScannerViewController(
            recognizedDataTypes: types,
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        DispatchQueue.main.async { try? scanner.startScanning() }
        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    static func dismantleUIViewController(_ uiViewController: DataScannerViewController, coordinator: Coordinator) {
        uiViewController.stopScanning()
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onScan: (String) -> Void
        private var fired = false

        init(onScan: @escaping (String) -> Void) { self.onScan = onScan }

        private func handle(_ items: [RecognizedItem]) {
            guard !fired else { return }
            for item in items {
                if case let .barcode(barcode) = item,
                   let value = barcode.payloadStringValue,
                   !value.isEmpty {
                    fired = true
                    onScan(value)
                    return
                }
            }
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            handle(addedItems)
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            handle([item])
        }
    }
}
