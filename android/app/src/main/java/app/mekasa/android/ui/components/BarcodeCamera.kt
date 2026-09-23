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
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
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
import androidx.lifecycle.compose.LocalLifecycleOwner
import app.mekasa.android.ui.theme.MekasaColor
import app.mekasa.android.ui.theme.MekasaType
import app.mekasa.android.ui.theme.Spacing
import androidx.compose.material3.Text
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/**
 * CameraX + ML Kit barcode preview. Calls [onBarcode] once per arm of [scanKey]
 * (change [scanKey] to re-arm after handling a code).
 */
@Composable
fun BarcodeCameraPreview(
    modifier: Modifier = Modifier,
    scanKey: Int = 0,
    onBarcode: (String) -> Unit,
) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    val handled = remember(scanKey) { AtomicBoolean(false) }
    val executor = remember { Executors.newSingleThreadExecutor() }

    DisposableEffect(Unit) {
        onDispose { executor.shutdown() }
    }

    AndroidView(
        modifier = modifier,
        factory = { ctx ->
            PreviewView(ctx).also { previewView ->
                val cameraProviderFuture = ProcessCameraProvider.getInstance(ctx)
                cameraProviderFuture.addListener(
                    {
                        val cameraProvider = cameraProviderFuture.get()
                        val preview = Preview.Builder().build().also {
                            it.setSurfaceProvider(previewView.surfaceProvider)
                        }
                        val analysis = ImageAnalysis.Builder()
                            .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                            .build()
                        val scanner = BarcodeScanning.getClient()
                        analysis.setAnalyzer(executor) { imageProxy ->
                            val media = imageProxy.image
                            if (media != null && !handled.get()) {
                                val image = InputImage.fromMediaImage(
                                    media,
                                    imageProxy.imageInfo.rotationDegrees,
                                )
                                scanner.process(image)
                                    .addOnSuccessListener { barcodes ->
                                        val value = barcodes.firstOrNull {
                                            it.format == Barcode.FORMAT_EAN_13 ||
                                                it.format == Barcode.FORMAT_EAN_8 ||
                                                it.format == Barcode.FORMAT_UPC_A ||
                                                it.format == Barcode.FORMAT_UPC_E ||
                                                it.rawValue != null
                                        }?.rawValue
                                        if (value != null && handled.compareAndSet(false, true)) {
                                            ContextCompat.getMainExecutor(ctx).execute {
                                                onBarcode(value)
                                            }
                                        }
                                    }
                                    .addOnCompleteListener { imageProxy.close() }
                            } else {
                                imageProxy.close()
                            }
                        }
                        runCatching {
                            cameraProvider.unbindAll()
                            cameraProvider.bindToLifecycle(
                                lifecycleOwner,
                                CameraSelector.DEFAULT_BACK_CAMERA,
                                preview,
                                analysis,
                            )
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
