package ng.rentaride.rent_a_ride_passenger

import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Tells Dart which Google features have keys (mirrors the iOS AppDelegate).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ng.rentaride/config")
            .setMethodCallHandler { call, result ->
                if (call.method == "googleConfig") {
                    val key = mapsKey()
                    result.success(mapOf(
                        "mapsConfigured" to key.isNotEmpty(),
                        "googleSignInConfigured" to false,
                        "mapsApiKey" to key,
                        "androidPackage" to packageName,
                        "androidCertSha1" to certSha1(),
                    ))
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun mapsKey(): String = try {
        val info = packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA)
        info.metaData?.getString("com.google.android.geo.API_KEY")?.trim().orEmpty()
    } catch (e: Exception) { "" }

    /** SHA-1 of the signing certificate, sent with Places requests so an
     *  Android-restricted key accepts them. */
    @Suppress("DEPRECATION")
    private fun certSha1(): String = try {
        val sig = if (Build.VERSION.SDK_INT >= 28) {
            packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNING_CERTIFICATES)
                .signingInfo?.apkContentsSigners?.firstOrNull()
        } else {
            packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNATURES).signatures?.firstOrNull()
        }
        sig?.toByteArray()?.let { bytes ->
            MessageDigest.getInstance("SHA-1").digest(bytes).joinToString("") { "%02X".format(it) }
        }.orEmpty()
    } catch (e: Exception) { "" }
}
