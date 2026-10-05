package dev.pawmate.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.app.Activity
import android.content.Intent

/** Exports selected attachments through Android's Storage Access Framework. */
class MainActivity : FlutterActivity() {
    private var pendingSave: MethodChannel.Result? = null
    private var pendingBytes: ByteArray? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.pawmate.app/attachments")
            .setMethodCallHandler { call, result ->
                if (call.method != "save") { result.notImplemented(); return@setMethodCallHandler }
                if (pendingSave != null) { result.error("busy", "Another save is active", null); return@setMethodCallHandler }
                val name = call.argument<String>("name")
                val bytes = call.argument<ByteArray>("bytes")
                if (name.isNullOrBlank() || name.contains('/') || name.contains('\\') || bytes == null || bytes.size > 20 * 1024 * 1024) {
                    result.error("invalid", "Invalid attachment", null); return@setMethodCallHandler
                }
                pendingSave = result
                pendingBytes = bytes
                try {
                    startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = call.argument<String>("content_type") ?: "application/octet-stream"
                        putExtra(Intent.EXTRA_TITLE, name)
                    }, 7301)
                } catch (_: Exception) {
                    pendingSave = null; pendingBytes = null
                    result.error("save_unavailable", "Cannot open document picker", null)
                }
            }
    }

    /** A cancelled picker writes nothing; chosen content URIs never become file paths. */
    @Deprecated("Android activity result bridge")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != 7301) return
        val result = pendingSave ?: return
        val bytes = pendingBytes
        pendingSave = null; pendingBytes = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null || bytes == null) { result.success(false); return }
        // Stream outside the UI thread; callbacks return to Flutter on the main thread.
        Thread {
            try {
                val output = contentResolver.openOutputStream(uri, "wt") ?: throw IllegalStateException()
                output.use { it.write(bytes) }
                runOnUiThread { result.success(true) }
            } catch (_: Exception) {
                runOnUiThread { result.error("save_failed", "Cannot save attachment", null) }
            }
        }.start()
    }
}
