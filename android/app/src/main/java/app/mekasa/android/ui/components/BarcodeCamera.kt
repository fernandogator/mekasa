package app.mekasa.android.ui.components

import android.Manifest
import android.content.pm.PackageManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LocalLifecycleOwner
import app.mekasa.android.ui.theme.MekasaColor
import app.mekasa.android.ui.theme.MekasaType
import app.mekasa.android.ui.theme.Spacing
import com.google.mlkit.vision.barcode.BarcodeScanner
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import java.util.concurrent.Executor
import java.util.concurrent.Executors
import java.util.concurrent.RejectedExecutionException
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicReference

/**
 * CameraX + ML Kit barcode preview. Calls [onBarcode] once per arm of [scanKey]
 * (change [scanKey] to re-arm after handling a code).
 */
@Suppress("UnsafeOptInUsageError")
@Composable
fun BarcodeCameraPreview(
    modifier: Modifier = Modifier,
    scanKey: Int = 0,
    onBarcode: (String) -> Unit,
) {
    val lifecycleOwner = LocalLifecycleOwner.current
    val handled = remember(scanKey) { AtomicBoolean(false) }
    val executor = remember { Executors.newSingleThreadExecutor() }
    val safeExecutor = remember(executor) {
        Executor { command ->
            if (!executor.isShutdown) {
                try {
                    executor.execute {
                        try {
                            command.run()
                        } catch (_: Throwable) {
                            // Catch any uncaught exception/error on background executor thread
                        }
                    }
                } catch (_: RejectedExecutionException) {
                    // Executor shut down concurrently, drop frame safely
                } catch (_: Throwable) {
                    // Ignore any unexpected executor error on shutdown
                }
            }
        }
    }
    val cameraProviderRef = remember { AtomicReference<ProcessCameraProvider?>(null) }
    val scannerRef = remember { AtomicReference<BarcodeScanner?>(null) }
    val analysisRef = remember { AtomicReference<ImageAnalysis?>(null) }
    val isDisposed = remember { AtomicBoolean(false) }

    DisposableEffect(lifecycleOwner) {
        onDispose {
            isDisposed.set(true)
            runCatching { analysisRef.getAndSet(null)?.clearAnalyzer() }
            runCatching { cameraProviderRef.getAndSet(null)?.unbindAll() }
            runCatching { scannerRef.getAndSet(null)?.close() }
            runCatching { executor.shutdownNow() }
        }
    }

    AndroidView(
        modifier = modifier,
        factory = { ctx ->
            PreviewView(ctx).also { previewView ->
                val cameraProviderFuture = ProcessCameraProvider.getInstance(ctx)
                cameraProviderFuture.addListener(
                    {
                        if (isDisposed.get()) return@addListener
                        val cameraProvider = runCatching { cameraProviderFuture.get() }.getOrNull()
                            ?: return@addListener
                        cameraProviderRef.set(cameraProvider)
                        if (isDisposed.get()) {
                            runCatching { cameraProvider.unbindAll() }
                            return@addListener
                        }
                        val preview = Preview.Builder().build().also {
                            it.setSurfaceProvider(previewView.surfaceProvider)
                        }
                        val analysis = ImageAnalysis.Builder()
                            .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                            .build()
                        analysisRef.set(analysis)

                        val scanner = runCatching {
                            BarcodeScanning.getClient(
                                BarcodeScannerOptions.Builder()
                                    .setBarcodeFormats(
                                        Barcode.FORMAT_EAN_13,
                                        Barcode.FORMAT_EAN_8,
                                        Barcode.FORMAT_UPC_A,
                                        Barcode.FORMAT_UPC_E,
                                    )
                                    .build(),
                            )
                        }.getOrNull()
                            ?: return@addListener
                        scannerRef.set(scanner)

                        analysis.setAnalyzer(safeExecutor) { imageProxy ->
                            if (isDisposed.get() || executor.isShutdown) {
                                runCatching { imageProxy.close() }
                                return@setAnalyzer
                            }
                            val media = runCatching { imageProxy.image }.getOrNull()
                            if (media != null && !handled.get()) {
                                val image = runCatching {
                                    InputImage.fromMediaImage(
                                        media,
                                        imageProxy.imageInfo.rotationDegrees,
                                    )
                                }.getOrNull()

                                val activeScanner = scannerRef.get()
                                if (image != null && activeScanner != null && !isDisposed.get()) {
                                    runCatching {
                                        activeScanner.process(image)
                                            .addOnSuccessListener { barcodes ->
                                                if (isDisposed.get()) return@addOnSuccessListener
                                                // Retail symbologies only; a QR / Code 128 on the
                                                // pack must not be sent to the UPC lookup.
                                                val value = barcodes.firstOrNull {
                                                    (
                                                        it.format == Barcode.FORMAT_EAN_13 ||
                                                            it.format == Barcode.FORMAT_EAN_8 ||
                                                            it.format == Barcode.FORMAT_UPC_A ||
                                                            it.format == Barcode.FORMAT_UPC_E
                                                        ) && !it.rawValue.isNullOrBlank()
                                                }?.rawValue
                                                if (value != null && handled.compareAndSet(false, true)) {
                                                    ContextCompat.getMainExecutor(ctx).execute {
                                                        if (!isDisposed.get()) {
                                                            onBarcode(value)
                                                        }
                                                    }
                                                }
                                            }
                                            .addOnFailureListener {
                                                // Ignore MLKit processing failure on shutdown/closed scanner
                                            }
                                            .addOnCompleteListener {
                                                runCatching { imageProxy.close() }
                                            }
                                    }.onFailure {
                                        runCatching { imageProxy.close() }
                                    }
                                } else {
                                    runCatching { imageProxy.close() }
                                }
                            } else {
                                runCatching { imageProxy.close() }
                            }
                        }

                        if (lifecycleOwner.lifecycle.currentState.isAtLeast(Lifecycle.State.STARTED) &&
                            !isDisposed.get()
                        ) {
                            runCatching {
                                cameraProvider.unbindAll()
                                cameraProvider.bindToLifecycle(
                                    lifecycleOwner,
                                    CameraSelector.DEFAULT_BACK_CAMERA,
                                    preview,
                                    analysis,
                                )
                            }
                        }
                    },
                    ContextCompat.getMainExecutor(ctx),
                )
            }
        },
        update = {
            // scanKey changes re-create handled via remember
        },
    )

    LaunchedEffect(scanKey) {
        handled.set(false)
    }
}

@Composable
fun BarcodeCameraOrPermission(
    modifier: Modifier = Modifier,
    scanKey: Int = 0,
    onBarcode: (String) -> Unit,
) {
    val context = LocalContext.current
    var granted by remember {
        mutableStateOf(
            ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) ==
                PackageManager.PERMISSION_GRANTED,
        )
    }
    val launcher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { granted = it }

    if (granted) {
        BarcodeCameraPreview(
            modifier = modifier
                .fillMaxWidth()
                .height(220.dp),
            scanKey = scanKey,
            onBarcode = onBarcode,
        )
    } else {
        SoftCard(modifier = modifier.fillMaxWidth()) {
            Text(
                text = "Camera permission needed to scan live.",
                style = MekasaType.body,
                color = MekasaColor.textMuted,
            )
            Box(modifier = Modifier.height(Spacing.sm))
            Text(
                text = "Tap Allow camera below.",
                style = MekasaType.label,
                color = MekasaColor.textMuted,
                modifier = Modifier.padding(bottom = Spacing.sm),
            )
            SecondaryButton(title = "Allow camera") {
                launcher.launch(Manifest.permission.CAMERA)
            }
        }
    }
}
