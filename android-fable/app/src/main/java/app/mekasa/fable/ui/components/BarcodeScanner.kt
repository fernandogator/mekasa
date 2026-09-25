package app.mekasa.fable.ui.components

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.util.Log
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.camera.core.CameraSelector
import androidx.camera.core.ExperimentalGetImage
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.QrCodeScanner
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.compose.LocalLifecycleOwner
import app.mekasa.fable.ui.TestTags
import app.mekasa.fable.ui.theme.MekasaTheme
import app.mekasa.fable.ui.theme.Shapes
import app.mekasa.fable.ui.theme.Space
import app.mekasa.fable.ui.theme.Type
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Live barcode preview. Fires [onBarcode] at most once per [generation]; bump the
 * generation after handling a code to arm the scanner again. Handles the CAMERA
 * runtime permission inline.
 */
@Composable
fun BarcodeScanner(
    generation: Int,
    onBarcode: (String) -> Unit,
    modifier: Modifier = Modifier,
    height: Int = 220,
) {
    val palette = MekasaTheme.palette
    val context = LocalContext.current
    var granted by remember { mutableStateOf(context.hasCameraPermission()) }
    val permissionLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted = it }

    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(height.dp)
            .clip(Shapes.card)
            .background(palette.brand)
            .testTag(TestTags.BARCODE_SCANNER),
    ) {
        if (granted) {
            CameraPreview(generation = generation, onBarcode = onBarcode, modifier = Modifier.fillMaxSize())
            Box(
                modifier = Modifier
                    .align(Alignment.Center)
                    .fillMaxWidth(0.72f)
                    .height((height * 0.42f).dp)
                    .border(2.dp, Color.White.copy(alpha = 0.85f), Shapes.well),
            )
            Text(
                "Point at a UPC / EAN barcode",
                style = Type.caption,
                color = Color.White.copy(alpha = 0.85f),
                modifier = Modifier.align(Alignment.BottomCenter).padding(Space.md),
            )
        } else {
            Column(
                modifier = Modifier.fillMaxSize().padding(Space.lg),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = androidx.compose.foundation.layout.Arrangement.Center,
            ) {
                Icon(Icons.Outlined.QrCodeScanner, contentDescription = null, tint = Color.White, modifier = Modifier.size(36.dp))
                Spacer(Modifier.height(Space.sm))
                Text("Camera access lets you scan barcodes live.", style = Type.caption, color = Color.White.copy(alpha = 0.85f))
                Spacer(Modifier.height(Space.md))
                SecondaryButton(
                    text = "Allow camera",
                    onClick = { permissionLauncher.launch(Manifest.permission.CAMERA) },
                    modifier = Modifier.testTag(TestTags.ALLOW_CAMERA),
                )
            }
        }
    }
}

private fun Context.hasCameraPermission(): Boolean =
    ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED

@Composable
private fun CameraPreview(
    generation: Int,
    onBarcode: (String) -> Unit,
    modifier: Modifier,
) {
    val lifecycleOwner = LocalLifecycleOwner.current
    val latestCallback by rememberUpdatedState(onBarcode)
    val controller = remember { ScannerController { code -> latestCallback(code) } }

    LaunchedEffect(generation) { controller.arm() }

    DisposableEffect(controller) {
        onDispose { controller.release() }
    }

    AndroidView(
        modifier = modifier,
        factory = { ctx ->
            PreviewView(ctx).apply {
                scaleType = PreviewView.ScaleType.FILL_CENTER
                controller.bind(ctx, lifecycleOwner, this)
            }
        },
    )
}

/**
 * Owns the CameraX provider, the analysis executor and the ML Kit client so the
 * composable above stays declarative. All teardown is best-effort: CameraX can
 * already be mid-shutdown when the composition leaves.
 */
private class ScannerController(private val onCode: (String) -> Unit) {
    private val executor: ExecutorService = Executors.newSingleThreadExecutor()
    private val released = AtomicBoolean(false)
    private val armed = AtomicBoolean(true)
    private var provider: ProcessCameraProvider? = null
    private var analysis: ImageAnalysis? = null

    private val scanner = BarcodeScanning.getClient(
        BarcodeScannerOptions.Builder()
            .setBarcodeFormats(
                Barcode.FORMAT_EAN_13,
                Barcode.FORMAT_EAN_8,
                Barcode.FORMAT_UPC_A,
                Barcode.FORMAT_UPC_E,
                Barcode.FORMAT_CODE_128,
                Barcode.FORMAT_QR_CODE,
            )
            .build(),
    )

    fun arm() = armed.set(true)

    fun bind(context: Context, lifecycleOwner: LifecycleOwner, previewView: PreviewView) {
        val future = ProcessCameraProvider.getInstance(context)
        future.addListener(
            {
                if (released.get()) return@addListener
                val cameraProvider = runCatching { future.get() }.getOrNull() ?: return@addListener
                provider = cameraProvider
                val preview = Preview.Builder().build().also { it.setSurfaceProvider(previewView.surfaceProvider) }
                val analyzer = ImageAnalysis.Builder()
                    .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                    .build()
                    .also { it.setAnalyzer(executor, ::analyze) }
                analysis = analyzer
                runCatching {
                    cameraProvider.unbindAll()
                    cameraProvider.bindToLifecycle(lifecycleOwner, CameraSelector.DEFAULT_BACK_CAMERA, preview, analyzer)
                }.onFailure { Log.w(TAG, "Camera bind failed", it) }
            },
            ContextCompat.getMainExecutor(context),
        )
    }

    @ExperimentalGetImage
    private fun analyze(proxy: ImageProxy) {
        if (released.get() || !armed.get()) {
            proxy.close()
            return
        }
        val media = proxy.image
        if (media == null) {
            proxy.close()
            return
        }
        val image = InputImage.fromMediaImage(media, proxy.imageInfo.rotationDegrees)
        scanner.process(image)
            .addOnSuccessListener { barcodes ->
                val value = barcodes.firstNotNullOfOrNull { it.rawValue?.takeIf { v -> v.isNotBlank() } }
                if (value != null && !released.get() && armed.compareAndSet(true, false)) {
                    onCode(value)
                }
            }
            .addOnFailureListener { Log.d(TAG, "Frame skipped: ${it.message}") }
            .addOnCompleteListener { proxy.close() }
    }

    fun release() {
        if (!released.compareAndSet(false, true)) return
        runCatching { analysis?.clearAnalyzer() }
        runCatching { provider?.unbindAll() }
        runCatching { scanner.close() }
        runCatching { executor.shutdown() }
    }

    private companion object {
        const val TAG = "BarcodeScanner"
    }
}
