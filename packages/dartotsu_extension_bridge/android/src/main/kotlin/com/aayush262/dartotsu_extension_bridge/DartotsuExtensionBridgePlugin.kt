package com.aayush262.dartotsu_extension_bridge

import android.app.Activity
import android.content.Context
import android.util.Log
import dalvik.system.DexClassLoader
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.EventChannel.EventSink as MethodEventSink
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.Result as MethodResult
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.isActive
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import android.net.Uri
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream
import java.lang.reflect.Method
import java.lang.reflect.Proxy
import java.lang.reflect.InvocationHandler

class DartotsuExtensionBridgePlugin : FlutterPlugin, ActivityAware {

    private val TAG = "DartotsuRuntimeBridge"
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    private lateinit var anymeXChannel: MethodChannel
    private lateinit var aniyomiChannel: MethodChannel
    private lateinit var cloudStreamChannel: MethodChannel
    private lateinit var videoStreamEventChannel: EventChannel
    private lateinit var loggingChannel: MethodChannel
    private lateinit var legacyLoggerChannel: MethodChannel
    private lateinit var legacyNetworkChannel: MethodChannel

    private var context: Context? = null
    private var activity: Activity? = null

    private var runtimeBridge: Any? = null
    private var bridgeClass: Class<*>? = null
    private var videoStreamJob: kotlinx.coroutines.Job? = null
    
    private var currentVideoStreamToken: String? = null
    private var currentVideoStreamUrl: String? = null
    private var isDevLoad: Boolean = false
    private var pluginBinding: FlutterPlugin.FlutterPluginBinding? = null
    private var loadedApkLength: Long = 0L

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        pluginBinding = binding
        context = binding.applicationContext

        anymeXChannel = MethodChannel(binding.binaryMessenger, "anymeXBridge")
        anymeXChannel.setMethodCallHandler { call, result -> handleAnymeX(call, result) }

        aniyomiChannel = MethodChannel(binding.binaryMessenger, "aniyomiExtensionBridge")
        aniyomiChannel.setMethodCallHandler { call, result -> handleAniyomi(call, result) }

        cloudStreamChannel = MethodChannel(binding.binaryMessenger, "cloudstreamExtensionBridge")
        cloudStreamChannel.setMethodCallHandler { call, result -> handleCloudStream(call, result) }

        legacyLoggerChannel = MethodChannel(binding.binaryMessenger, "flutterKotlinBridge.logger")
        legacyLoggerChannel.setMethodCallHandler { call, result -> result.success(null) }

        legacyNetworkChannel = MethodChannel(binding.binaryMessenger, "flutterKotlinBridge.network")
        legacyNetworkChannel.setMethodCallHandler { call, result -> result.success(null) }

        videoStreamEventChannel = EventChannel(binding.binaryMessenger, "cloudstreamExtensionBridge/videoStream")
        videoStreamEventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: MethodEventSink?) {
                val args = arguments as? Map<*, *> ?: return
                val epMap = toMapArg(args["episode"])
                val apiName = (args["apiName"] as? String)
                    ?: (args["sourceId"] as? String) ?: return
                val url = (args["url"] as? String)
                    ?: (epMap["url"] as? String) ?: return
                val sessionToken = (args["parameters"] as? Map<String, Any?>)?.get("token") as? String
                val params = (args["parameters"] as? Map<String, Any?>)?.toMutableMap() ?: mutableMapOf()
                if (args.containsKey("token")) {
                    params["token"] = args["token"]
                }
                handleVideoStream(apiName, url, params, events, sessionToken)
            }
            override fun onCancel(arguments: Any?) {
                videoStreamJob?.cancel()
                videoStreamJob = null
            }
        })

        loggingChannel = MethodChannel(binding.binaryMessenger, "anymexLogger")
        loggingChannel.setMethodCallHandler { call, result ->
            if (call.method == "ready") {
                flutterReady = true
                logQueue.forEach { logMap ->
                    try {
                        loggingChannel.invokeMethod("log", logMap)
                    } catch (e: Exception) {}
                }
                logQueue.clear()
                result.success(null)
            } else {
                result.notImplemented()
            }
        }

        scope.launch {
            ensureBridgeLoaded()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        pluginBinding = null
        anymeXChannel.setMethodCallHandler(null)
        aniyomiChannel.setMethodCallHandler(null)
        cloudStreamChannel.setMethodCallHandler(null)
        legacyLoggerChannel.setMethodCallHandler(null)
        legacyNetworkChannel.setMethodCallHandler(null)
        videoStreamEventChannel.setStreamHandler(null)
        videoStreamJob?.cancel()
        scope.cancel()
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    @Synchronized
    private fun ensureBridgeLoaded(): Boolean {
        if (runtimeBridge != null && loadedApkLength != 15538693L) return true
        val ctx = effectiveContext() ?: return false

        // Purge any obsolete cached APKs (specifically the 15538693-byte broken one)
        try {
            val filesDir = ctx.filesDir
            filesDir.listFiles()?.forEach { file ->
                if (file.name.startsWith("anymex_runtime_") && (file.name.contains("15538693") || file.length() == 15538693L)) {
                    Log.i(TAG, "Purging obsolete runtime APK: ${file.name}")
                    file.delete()
                }
            }
        } catch (_: Exception) {}

        val assetCandidates = mutableListOf<String>()
        try {
            pluginBinding?.flutterAssets?.getAssetFilePathByName("assets/runtime/anymex_runtime_host.apk")?.let {
                assetCandidates.add(it)
            }
        } catch (_: Exception) {}
        assetCandidates.add("flutter_assets/assets/runtime/anymex_runtime_host.apk")
        assetCandidates.add("assets/runtime/anymex_runtime_host.apk")

        for (assetPath in assetCandidates) {
            try {
                val targetApk = File(ctx.filesDir, "anymex_runtime_host.apk")
                val tmp = File(ctx.filesDir, "anymex_runtime_host.apk.tmp")
                if (tmp.exists()) {
                    tmp.setWritable(true)
                    tmp.delete()
                }
                ctx.assets.open(assetPath).use { input ->
                    FileOutputStream(tmp).use { output ->
                        input.copyTo(output)
                    }
                }
                if (tmp.exists() && tmp.length() > 5 * 1024 * 1024) {
                    val appUpdateTime = try {
                        ctx.packageManager.getPackageInfo(ctx.packageName, 0).lastUpdateTime
                    } catch (_: Exception) { 0L }
                    val shouldUpdate = !targetApk.exists() || 
                                       targetApk.length() != tmp.length() || 
                                       targetApk.lastModified() < appUpdateTime ||
                                       !targetApk.canRead()

                    if (shouldUpdate) {
                        if (targetApk.exists()) {
                            targetApk.setWritable(true)
                            targetApk.delete()
                        }
                        val renamed = tmp.renameTo(targetApk)
                        if (!renamed) {
                            tmp.inputStream().use { input ->
                                FileOutputStream(targetApk).use { output ->
                                    input.copyTo(output)
                                }
                            }
                            tmp.setWritable(true)
                            tmp.delete()
                        }
                        targetApk.setReadOnly()

                        // Delete any old cached APKs and dex caches so fresh classes are loaded
                        ctx.filesDir.listFiles()?.forEach { file ->
                            if (file.name.startsWith("anymex_runtime_") && file.name.endsWith(".apk")) {
                                file.setWritable(true)
                                file.delete()
                            }
                        }
                        ctx.cacheDir.listFiles()?.forEach { file ->
                            if (file.isDirectory && (file.name.startsWith("anymex_dex_") || file.name.startsWith("anymex_libs_"))) {
                                file.deleteRecursively()
                            }
                        }
                        try {
                            val codeCache = File(ctx.codeCacheDir, "runtime_opt")
                            if (codeCache.exists()) codeCache.deleteRecursively()
                        } catch (_: Exception) {}

                        Log.i(TAG, "Updated runtime host from asset $assetPath to ${targetApk.absolutePath}")
                    } else {
                        tmp.setWritable(true)
                        tmp.delete()
                    }
                }
                if (targetApk.exists() && targetApk.length() > 5 * 1024 * 1024 && targetApk.length() != 15538693L) {
                    if (loadAnymeXRuntimeHost(targetApk.absolutePath)) {
                        return true
                    }
                }
            } catch (e: Exception) {
                Log.d(TAG, "Asset $assetPath could not be loaded: ${e.message}")
            }
        }

        try {
            val filesDir = ctx.filesDir
            val cachedApks = filesDir.listFiles()?.filter {
                ((it.name.startsWith("anymex_runtime_") && it.name.endsWith(".apk")) || it.name == "anymex_runtime_host.apk") &&
                it.length() != 15538693L && !it.name.contains("15538693")
            }?.sortedByDescending { it.lastModified() }

            if (!cachedApks.isNullOrEmpty()) {
                for (cachedApk in cachedApks) {
                    if (cachedApk.exists() && cachedApk.length() > 5 * 1024 * 1024) {
                        Log.i(TAG, "Attempting load from cached runtime host APK: ${cachedApk.absolutePath}")
                        if (loadAnymeXRuntimeHost(cachedApk.absolutePath)) {
                            return true
                        }
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error checking cached runtime host: ${e.message}")
        }

        return runtimeBridge != null
    }

    private fun loadAnymeXRuntimeHost(apkPath: String, settingsMap: Map<String, Any?>? = null): Boolean {
        Log.i(TAG, "loadAnymeXRuntimeHost called with: $apkPath")
        val ctx = context ?: run {
            Log.e(TAG, "loadAnymeXRuntimeHost: context is null")
            return false
        }

        var currentCacheApk: File? = null
        val originalApk = File(apkPath)

        return try {
            if (originalApk.length() == 15538693L) {
                Log.w(TAG, "Rejecting obsolete runtime APK with length 15538693")
                originalApk.delete()
                return false
            }

            runtimeBridge = null
            bridgeClass = null

            if (!originalApk.exists()) {
                Log.e(TAG, "APK does not exist at path: $apkPath")
                return false
            }

            try {
                java.util.zip.ZipFile(originalApk).use { zip ->
                    if (zip.getEntry("classes.dex") == null) {
                        Log.e(TAG, "originalApk is missing classes.dex")
                        if (originalApk.name == "anymex_runtime_host.apk") {
                            originalApk.delete()
                        }
                        return false
                    }
                }
            } catch (ze: Throwable) {
                Log.e(TAG, "originalApk is not a valid zip archive: ${ze.message}")
                if (originalApk.name == "anymex_runtime_host.apk") {
                    originalApk.delete()
                }
                return false
            }

            val appUpdateTime = try {
                ctx.packageManager.getPackageInfo(ctx.packageName, 0).lastUpdateTime
            } catch (_: Exception) { 0L }

            val cacheApkName = "anymex_runtime_${originalApk.length()}_${originalApk.lastModified()}.apk"
            val cacheApk = File(ctx.filesDir, cacheApkName)
            currentCacheApk = cacheApk

            val isCacheValid = cacheApk.exists() && 
                               cacheApk.length() == originalApk.length() && 
                               cacheApk.lastModified() >= appUpdateTime

            if (!isCacheValid) {
                Log.i(TAG, "Creating new cached APK: $cacheApkName")
                ctx.filesDir.listFiles()?.forEach { file ->
                    if (file.name.startsWith("anymex_runtime_") && file.name.endsWith(".apk")) {
                        Log.d(TAG, "Deleting old cached APK: ${file.name}")
                        file.setWritable(true)
                        file.delete()
                    }
                }

                originalApk.inputStream().use { input ->
                    FileOutputStream(cacheApk).use { output ->
                        input.copyTo(output)
                    }
                }
                cacheApk.setReadOnly()
            } else {
                Log.i(TAG, "Using existing cached APK: $cacheApkName")
                cacheApk.setReadOnly()
            }

            val optimizedDir = File(ctx.cacheDir, "anymex_dex_${System.currentTimeMillis()}")
            optimizedDir.mkdirs()

            val libsDir = File(ctx.cacheDir, "anymex_libs_${System.currentTimeMillis()}")
            libsDir.mkdirs()

            try {
                java.util.zip.ZipFile(cacheApk).use { zip ->
                    val abisList = android.os.Build.SUPPORTED_ABIS
                    var selectedAbi: String? = null
                    
                    for (abi in abisList) {
                        val prefix = "lib/$abi/"
                        var found = false
                        val entriesEnum = zip.entries()
                        while (entriesEnum.hasMoreElements()) {
                            val entry = entriesEnum.nextElement()
                            if (entry.name.startsWith(prefix) && entry.name.endsWith(".so")) {
                                found = true
                                break
                            }
                        }
                        if (found) {
                            selectedAbi = abi
                            break
                        }
                    }

                    if (selectedAbi != null) {
                        Log.i(TAG, "Extracting native libraries for ABI: $selectedAbi")
                        val prefix = "lib/$selectedAbi/"
                        val entriesEnum = zip.entries()
                        while (entriesEnum.hasMoreElements()) {
                            val entry = entriesEnum.nextElement()
                            if (entry.name.startsWith(prefix) && entry.name.endsWith(".so")) {
                                val libName = entry.name.substringAfterLast('/')
                                val outFile = File(libsDir, libName)
                                zip.getInputStream(entry).use { input ->
                                    FileOutputStream(outFile).use { output ->
                                        input.copyTo(output)
                                    }
                                }
                            }
                        }
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to extract native libraries: ${e.message}", e)
            }

            val loader = ChildFirstClassLoader(
                cacheApk.absolutePath,
                optimizedDir.absolutePath,
                libsDir.absolutePath,
                ctx.classLoader!!
            )

            bridgeClass = loader.loadClass("com.anymex.runtimehost.RuntimeBridge")
            runtimeBridge = bridgeClass!!.getField("INSTANCE").get(null)
            
            try {
                val loggerClass = loader.loadClass("com.anymex.runtimehost.Logger")
                val setLogCallbackMethod = loggerClass.getMethod("setLogCallback", Any::class.java, Method::class.java)
                val ourLogMethod = DartotsuExtensionBridgePlugin::class.java.getMethod(
                    "logFromHost",
                    String::class.java,
                    String::class.java,
                    String::class.java
                )
                setLogCallbackMethod.invoke(null, this, ourLogMethod)
            } catch (e: Throwable) {
                Log.e(TAG, "Failed to register Logger callback: ${e.message}")
            }

            Log.i(TAG, "Dartotsu Runtime Bridge initialized successfully")
            
            try {
                call("initialize", ctx, settingsMap)
            } catch (e: Throwable) {
                Log.e(TAG, "Failed to initialize RuntimeBridge: ${e.message}")
            }

            true
        } catch (e: Throwable) {
            Log.e(TAG, "Failed to load Runtime Host APK: ${e.message}")
            false
        }
    }

    private fun handleAnymeX(call: MethodCall, result: MethodResult) {
        when (call.method) {
            "getAbi" -> {
                val primaryAbi = android.os.Build.SUPPORTED_ABIS.firstOrNull() ?: "arm64-v8a"
                result.success(primaryAbi)
            }
            "loadAnymeXRuntimeHost" -> {
                val path = call.argument<String>("path")
                val settingsMap = call.argument<Map<String, Any?>>("settings")
                if (path == null) {
                    result.error("INVALID_ARG", "Path cannot be null", null)
                    return
                }
                scope.launch {
                    val originalApk = File(path)
                    val needsReload = runtimeBridge == null || loadedApkLength != originalApk.length() || loadedApkLength == 15538693L
                    val success = if (!needsReload) true else loadAnymeXRuntimeHost(path, settingsMap)
                    withContext(Dispatchers.Main) {
                        result.success(success)
                    }
                }
            }
            "getTorrServerBinaryPath" -> {
                val ctx = effectiveContext()
                val nativeDir = ctx?.applicationInfo?.nativeLibraryDir
                if (nativeDir != null) {
                    val libFile = File(nativeDir, "libtorrserver.so")
                    if (libFile.exists()) {
                        result.success(libFile.absolutePath)
                        return
                    }
                }
                result.success(null)
            }
            "isLoaded" -> {
                result.success(runtimeBridge != null)
            }
            "cancelRequest" -> {
                val token = call.argument<String>("token")
                if (token == null) {
                    result.error("INVALID_ARG", "Token cannot be null", null)
                    return
                }
                scope.launch {
                    try {
                        val res = call("cancelRequest", token) as? Boolean ?: false
                        withContext(Dispatchers.Main) {
                            result.success(res)
                        }
                    } catch (e: Throwable) {
                        sendError(result, "cancelRequest", e)
                    }
                }
            }
            "setCookies" -> {
                val url = call.argument<String>("url")
                val cookieString = call.argument<String>("cookies") ?: call.argument<String>("cookieString")
                if (url.isNullOrBlank() || cookieString.isNullOrBlank()) {
                    result.error("INVALID_ARG", "url and cookies are required", null)
                    return
                }
                try {
                    val mgr = android.webkit.CookieManager.getInstance()
                    mgr.setAcceptCookie(true)
                    val rawCookies = cookieString.split(";").map { it.trim() }.filter { it.isNotEmpty() }
                    for (cookie in rawCookies) {
                        mgr.setCookie(url, cookie)
                    }
                    mgr.flush()
                    result.success(null)
                } catch (e: Exception) {
                    result.error("COOKIE_ERROR", e.message, null)
                }
            }
            "setUserAgent" -> {
                val url = call.argument<String>("url")
                val userAgent = call.argument<String>("userAgent")
                if (url.isNullOrBlank() || userAgent.isNullOrBlank()) {
                    result.error("INVALID_ARG", "url and userAgent are required", null)
                    return
                }
                try {
                    val host = android.net.Uri.parse(url).host ?: url
                    System.setProperty("anymex.ua.$host", userAgent)
                    result.success(null)
                } catch (e: Exception) {
                    result.error("UA_ERROR", e.message, null)
                }
            }
            else -> result.notImplemented()
        }
    }

    @Suppress("UNCHECKED_CAST")
    private fun handleAniyomi(call: MethodCall, result: MethodResult) {
        if (!ensureLoaded(result)) return
        val ctx = effectiveContext() ?: return result.error("NO_CTX", "No context", null)

        scope.launch {
            try {
                val res: Any? = when (call.method) {
                    "loadPlugin" -> {
                        // Return true safely for backwards compatibility with callers
                        true
                    }
                    "getInstalledAnimeExtensions" -> {
                        val path = call.arguments as? String?
                        val effectivePath = if (path.isNullOrBlank()) null else path
                        call("getInstalledAnimeExtensions", ctx, effectivePath)
                    }
                    "getInstalledMangaExtensions" -> {
                        val path = call.arguments as? String?
                        val effectivePath = if (path.isNullOrBlank()) null else path
                        call("getInstalledMangaExtensions", ctx, effectivePath)
                    }
                    "installSourceInternal" -> {
                        val apkPath = call.argument<String>("apkPath")
                            ?: (call.arguments as? Map<*, *>)?.get("apkPath") as? String
                        val isAnime = (call.argument<Boolean>("isAnime")
                            ?: (call.arguments as? Map<*, *>)?.get("isAnime") as? Boolean) ?: true
                        if (apkPath.isNullOrBlank()) {
                            result.error("INVALID_ARG", "apkPath is required", null)
                            return@launch
                        }
                        val success = installSourceInternal(ctx, apkPath, isAnime)
                        withContext(Dispatchers.Main) { result.success(success) }
                        return@launch
                    }
                    "uninstallSourceInternal" -> {
                        val packageName = call.argument<String>("packageName")
                            ?: (call.arguments as? Map<*, *>)?.get("packageName") as? String
                        val isAnime = (call.argument<Boolean>("isAnime")
                            ?: (call.arguments as? Map<*, *>)?.get("isAnime") as? Boolean) ?: true
                        if (packageName.isNullOrBlank()) {
                            result.error("INVALID_ARG", "packageName is required", null)
                            return@launch
                        }
                        val success = uninstallSourceInternal(ctx, packageName, isAnime)
                        withContext(Dispatchers.Main) { result.success(success) }
                        return@launch
                    }
                    "getPopular" -> {
                        val args = call.arguments as Map<*, *>
                        call("aniyomiGetPopular", ctx,
                            args["sourceId"] as String,
                            args["isAnime"] as Boolean,
                            args["page"] as Int,
                            args["parameters"] as? Map<String, Any?>)
                    }
                    "getLatestUpdates" -> {
                        val args = call.arguments as Map<*, *>
                        call("aniyomiGetLatestUpdates", ctx,
                            args["sourceId"] as String,
                            args["isAnime"] as Boolean,
                            args["page"] as Int,
                            args["parameters"] as? Map<String, Any?>)
                    }
                    "search" -> {
                        val args = call.arguments as Map<*, *>
                        call("aniyomiSearch", ctx,
                            args["sourceId"] as String,
                            args["isAnime"] as Boolean,
                            args["query"] as String,
                            args["page"] as Int,
                            args["filters"] as? List<*>,
                            args["parameters"] as? Map<String, Any?>)
                    }
                    "getFilterList" -> {
                        val args = call.arguments as Map<*, *>
                        call("aniyomiGetFilterList", ctx,
                            args["sourceId"] as String,
                            args["isAnime"] as Boolean)
                    }
                    "getDetail", "getDetails" -> {
                        val args = call.arguments as Map<*, *>
                        val mediaMap = mutableMapOf<String, Any?>()
                        val rawMap = toMapArg(args["media"])
                        if (rawMap.isNotEmpty()) {
                            mediaMap.putAll(rawMap)
                        } else {
                            mediaMap["title"] = args["title"] ?: ""
                            mediaMap["url"] = args["url"] ?: ""
                        }

                        try {
                            call("aniyomiGetDetail", ctx,
                                args["sourceId"] as String,
                                args["isAnime"] as Boolean,
                                mediaMap,
                                args["parameters"] as? Map<String, Any?>)
                        } catch (e: Throwable) {
                            Log.e(TAG, "aniyomiGetDetail error: ${e.message}", e)
                            mapOf(
                                "title" to (mediaMap["title"] ?: ""),
                                "url" to (mediaMap["url"] ?: ""),
                                "cover" to (mediaMap["cover"] ?: mediaMap["thumbnail_url"]),
                                "episodes" to emptyList<Any>()
                            )
                        }
                    }
                    "getVideoList" -> {
                        val args = call.arguments as Map<*, *>
                        val epMap = toMapArg(args["episode"])
                        val ep = if (epMap.isNotEmpty()) epMap else mapOf(
                            "url" to (args["url"] ?: ""),
                            "name" to (args["name"] ?: "")
                        )
                        call("aniyomiGetVideoList", ctx,
                            args["sourceId"] as String,
                            args["isAnime"] as? Boolean ?: true,
                            ep,
                            args["parameters"] as? Map<String, Any?>)
                    }
                    "stopHttpServer" -> {
                        val args = call.arguments as Map<*, *>
                        call("aniyomiStopHttpServer", ctx,
                            args["sourceId"] as String,
                            args["isAnime"] as Boolean)
                    }
                    "getImageBytes" -> {
                        val args = call.arguments as Map<*, *>
                        call("aniyomiGetImageBytes", ctx,
                            args["sourceId"] as String,
                            args["isAnime"] as Boolean,
                            args["url"] as String)
                    }
                    "getPageList" -> {
                        val args = call.arguments as Map<*, *>
                        val epMap = toMapArg(args["episode"])
                        val ep = if (epMap.isNotEmpty()) epMap else mapOf(
                            "url" to (args["url"] ?: ""),
                            "name" to (args["name"] ?: "")
                        )
                        call("aniyomiGetPageList", ctx,
                            args["sourceId"] as String,
                            args["isAnime"] as? Boolean ?: false,
                            ep,
                            args["parameters"] as? Map<String, Any?>)
                    }
                    "getPreference" -> {
                        val args = call.arguments as Map<*, *>
                        call("aniyomiGetPreference", ctx,
                            args["sourceId"] as String,
                            args["isAnime"] as Boolean)
                    }
                    "saveSourcePreference" -> {
                        val args = call.arguments as Map<*, *>
                        call("aniyomiSavePreference", ctx,
                            args["sourceId"] as String,
                            args["key"] as String,
                            args["action"] as? String,
                            args["value"])
                    }
                    else -> { withContext(Dispatchers.Main) { result.notImplemented() }; return@launch }
                }
                withContext(Dispatchers.Main) { result.success(res) }
            } catch (e: Throwable) {
                sendError(result, "Aniyomi.${call.method}", e)
            }
        }
    }

    @Suppress("UNCHECKED_CAST")
    private fun handleCloudStream(call: MethodCall, result: MethodResult) {
        if (!ensureLoaded(result)) return
        val ctx = effectiveContext() ?: return result.error("NO_CTX", "No context", null)

        when (call.method) {
            "initialize" -> {
                try {
                    call("initialize", ctx)
                    result.success(null)
                } catch (e: Throwable) {
                    sendError(result, "csInitialize", e)
                }
                return
            }
            "getRegisteredProviders", "getInstalledExtensions" -> {
                try {
                    result.success(call("csGetRegisteredProviders"))
                } catch (e: Throwable) {
                    sendError(result, "csGetRegisteredProviders", e)
                }
                return
            }
        }

        scope.launch {
            try {
                val res: Any? = when (call.method) {
                    "loadPlugin" -> {
                        val path = call.argument<String>("path")
                            ?: (call.arguments as? Map<*, *>)?.get("path") as? String
                            ?: return@launch withContext(Dispatchers.Main) {
                                result.error("INVALID_ARG", "path required", null)
                            }
                        call("csLoadPlugin", ctx, path)
                    }
                    "search" -> {
                        val args = call.arguments as? Map<*, *>
                        val query = (call.argument<String>("query")
                            ?: (args?.get("query") as? String) ?: "").toString()
                        val apiName = (call.argument<String>("apiName")
                            ?: (args?.get("apiName") as? String)
                            ?: (args?.get("sourceId") as? String))?.toString()
                        val page = call.argument<Int>("page")
                            ?: (args?.get("page") as? Int) ?: 1
                        val parameters = call.argument<Map<String, Any?>>("parameters")
                            ?: (args?.get("parameters") as? Map<String, Any?>)
                        call("csSearch", ctx, query, apiName, page, parameters)
                    }
                    "getDetail", "load" -> {
                        val args = call.arguments as? Map<*, *>
                        val mediaMap = toMapArg(args?.get("media"))
                        val apiName = (call.argument<String>("apiName")
                            ?: (args?.get("apiName") as? String)
                            ?: (args?.get("sourceId") as? String) ?: "").toString()
                        val url = (call.argument<String>("url")
                            ?: (args?.get("url") as? String)
                            ?: (mediaMap["url"] as? String) ?: "").toString()
                        val parameters = call.argument<Map<String, Any?>>("parameters")
                            ?: (args?.get("parameters") as? Map<String, Any?>)
                        call("csGetDetail", ctx, apiName, url, parameters)
                    }
                    "getVideoList", "loadLinks" -> {
                        val args = call.arguments as? Map<*, *>
                        val epMap = toMapArg(args?.get("episode"))
                        val apiName = (call.argument<String>("apiName")
                            ?: (args?.get("apiName") as? String)
                            ?: (args?.get("sourceId") as? String) ?: "").toString()
                        val url = (call.argument<String>("url")
                            ?: (args?.get("url") as? String)
                            ?: (epMap["url"] as? String) ?: "").toString()
                        val parameters = call.argument<Map<String, Any?>>("parameters")
                            ?: (args?.get("parameters") as? Map<String, Any?>)
                        call("csGetVideoList", ctx, apiName, url, parameters)
                    }
                    "deletePlugin" -> {
                        val internalName = call.argument<String>("internalName")
                            ?: (call.arguments as? Map<*, *>)?.get("internalName") as? String
                            ?: return@launch withContext(Dispatchers.Main) {
                                result.error("INVALID_ARG", "internalName required", null)
                            }
                        call("csUnloadPlugin", internalName)
                    }
                    "getExtensionSettings" -> {
                        val pluginName = call.argument<String>("pluginName")
                            ?: (call.arguments as? Map<*, *>)?.get("pluginName") as? String ?: ""
                        call("csGetExtensionSettings", ctx, pluginName)
                    }
                    "setExtensionSettings" -> {
                        val pluginName = call.argument<String>("pluginName")
                            ?: (call.arguments as? Map<*, *>)?.get("pluginName") as? String ?: ""
                        val key = call.argument<String>("key")
                            ?: (call.arguments as? Map<*, *>)?.get("key") as? String ?: ""
                        val value = call.argument<Any>("value")
                            ?: (call.arguments as? Map<*, *>)?.get("value")
                        call("csSetExtensionSettings", ctx, pluginName, key, value)
                    }
                    "openSettings" -> {
                        val pluginName = call.argument<String>("pluginName")
                            ?: (call.arguments as? Map<*, *>)?.get("pluginName") as? String ?: ""
                        val settingsActivity = activity ?: ctx
                        withContext(Dispatchers.Main) {
                            call("csOpenSettings", settingsActivity, pluginName)
                        }
                    }
                    else -> { withContext(Dispatchers.Main) { result.notImplemented() }; return@launch }
                }
                withContext(Dispatchers.Main) { result.success(res) }
            } catch (e: Throwable) {
                sendError(result, "CloudStream.${call.method}", e)
            }
        }
    }

    @Suppress("UNCHECKED_CAST")
    private fun handleVideoStream(apiName: String, url: String, parameters: Map<String, Any?>?, events: MethodEventSink?, sessionToken: String?) {
        val ctx = effectiveContext() ?: run {
            events?.error("NO_CTX", "No context available", null)
            events?.endOfStream()
            return
        }
        
        if (videoStreamJob?.isActive == true && currentVideoStreamToken == sessionToken && currentVideoStreamUrl == url) {
            Log.d(TAG, "Redundant stream request for token $sessionToken, ignoring.")
            return
        }

        videoStreamJob?.cancel()
        videoStreamJob = scope.launch {
            currentVideoStreamToken = sessionToken
            currentVideoStreamUrl = url
            val active = java.util.concurrent.atomic.AtomicBoolean(true)
            val mainHandler = android.os.Handler(android.os.Looper.getMainLooper())
            try {
                val cls = bridgeClass ?: throw IllegalStateException("Runtime Host not loaded")
                val loader = cls.classLoader ?: throw IllegalStateException("No Host ClassLoader")
                val function1Class = loader.loadClass("kotlin.jvm.functions.Function1")
                val unitClass = loader.loadClass("kotlin.Unit")
                val unitInstance = unitClass.getField("INSTANCE").get(null)

                val pendingVideos = java.util.concurrent.ConcurrentLinkedQueue<Any?>()
                val flushScheduled = java.util.concurrent.atomic.AtomicBoolean(false)

                val flushRunnable = object : Runnable {
                    override fun run() {
                        flushScheduled.set(false)
                        if (!active.get()) return
                        while (pendingVideos.isNotEmpty()) {
                            val item = pendingVideos.poll() ?: break
                            try { events?.success(item) } catch (_: Exception) {}
                        }
                    }
                }

                val proxyCallback = Proxy.newProxyInstance(
                    loader,
                    arrayOf(function1Class),
                    object : InvocationHandler {
                        override fun invoke(proxy: Any?, method: Method?, args: Array<out Any?>?): Any? {
                            if (method?.name == "invoke" && active.get()) {
                                val video = args?.get(0)
                                pendingVideos.add(video)
                                if (flushScheduled.compareAndSet(false, true)) {
                                    mainHandler.post(flushRunnable)
                                }
                                return unitInstance
                            }
                            return null
                        }
                    }
                )

                call("csGetVideoListStream", ctx, apiName, url, proxyCallback, parameters)

                active.set(false)
                mainHandler.post {
                    while (pendingVideos.isNotEmpty()) {
                        val item = pendingVideos.poll() ?: break
                        try { events?.success(item) } catch (_: Exception) {}
                    }
                    events?.endOfStream()
                }
            } catch (e: kotlinx.coroutines.CancellationException) {
                active.set(false)
                throw e
            } catch (e: Throwable) {
                active.set(false)
                sendError(result = object : MethodResult {
                    override fun success(res: Any?) {}
                    override fun error(code: String, msg: String?, details: Any?) {
                        events?.error(code, msg, details)
                    }
                    override fun notImplemented() {
                        events?.endOfStream()
                    }
                }, methodName = "videoStream", e = e)
                withContext(Dispatchers.Main) { events?.endOfStream() }
            }
        }
    }

    private fun sendError(result: MethodResult, methodName: String, e: Throwable) {
        val realError = (e as? java.lang.reflect.InvocationTargetException)?.targetException ?: e
        val stackTrace = Log.getStackTraceString(e) 
        val errorMessage = realError.message ?: realError.toString()
        val detailedError = "Method: $methodName\nError: $errorMessage\n$stackTrace"
        
        Log.e(TAG, detailedError)
        logToFlutter("ERROR", "BRIDGE", detailedError)
        
        scope.launch(Dispatchers.Main) {
            result.error("BRIDGE_ERROR", errorMessage, detailedError)
        }
    }

    private fun call(methodName: String, vararg args: Any?): Any? {
        val bridge = runtimeBridge ?: throw IllegalStateException("Runtime Host not loaded")
        val cls = bridgeClass ?: throw IllegalStateException("Runtime Host class not loaded")

        val method = cls.methods.filter { it.name == methodName }
            .firstOrNull { it.parameterTypes.size == args.size }
            ?: cls.methods.firstOrNull { it.name == methodName }
            ?: throw NoSuchMethodException("No method '$methodName' in RuntimeBridge")

        val effectiveArgs = if (method.parameterTypes.size != args.size) {
            logToFlutter("WARNING", "BRIDGE", "Argument count mismatch for $methodName. Expected ${method.parameterTypes.size}, got ${args.size}. Adjusting.")
            if (args.size > method.parameterTypes.size) {
                args.take(method.parameterTypes.size).toTypedArray()
            } else {
                val padded = args.toMutableList()
                while (padded.size < method.parameterTypes.size) padded.add(null)
                padded.toTypedArray()
            }
        } else {
            args
        }

        logToFlutter("INFO", "BRIDGE", "Calling Method: RuntimeBridge.$methodName")
        val result = method.invoke(bridge, *effectiveArgs)
        logToFlutter("INFO", "BRIDGE", "Method '$methodName' completed successfully")

        return result
    }

    private fun toMapArg(arg: Any?): Map<String, Any?> {
        if (arg == null) return emptyMap()
        if (arg is Map<*, *>) {
            val result = mutableMapOf<String, Any?>()
            arg.forEach { (k, v) -> if (k != null) result[k.toString()] = v }
            return result
        }
        if (arg is String && arg.isNotBlank()) {
            try {
                val json = org.json.JSONObject(arg)
                val map = mutableMapOf<String, Any?>()
                val keys = json.keys()
                while (keys.hasNext()) {
                    val key = keys.next()
                    val value = json.opt(key)
                    map[key] = if (value === org.json.JSONObject.NULL) null else value
                }
                return map
            } catch (_: Exception) {}
        }
        return emptyMap()
    }

    private fun ensureLoaded(result: MethodResult): Boolean {
        if (runtimeBridge != null) return true
        if (ensureBridgeLoaded()) return true
        result.error("NOT_LOADED", "Runtime Host APK not loaded. Call loadAnymeXRuntimeHost first.", null)
        return false
    }

    private fun effectiveContext(): Context? = activity ?: context

    private val logQueue = mutableListOf<Map<String, String>>()
    private var flutterReady = false

    fun logFromHost(level: String, tag: String, message: String) {
        logToFlutter(level, tag, message)
    }

    private fun logToFlutter(level: String, tag: String, message: String) {
        scope.launch(Dispatchers.Main) {
            val logMap = mapOf("level" to level, "tag" to tag, "message" to message)
            if (flutterReady) {
                try {
                    loggingChannel.invokeMethod("log", logMap)
                } catch (e: Exception) {}
            } else {
                logQueue.add(logMap)
                if (logQueue.size > 2000) logQueue.removeAt(0)
            }
        }
    }


    private fun installSourceInternal(context: Context, apkPath: String, isAnime: Boolean): Boolean {
        return try {
            val pm = context.packageManager
            val packageInfo = pm.getPackageArchiveInfo(apkPath, 0)
                ?: throw IllegalArgumentException("Invalid APK file at $apkPath")
            val packageName = packageInfo.packageName

            val dirName = if (isAnime) "exts" else "exts_manga"
            val privateDir = File(context.filesDir, dirName)
            if (!privateDir.exists()) {
                privateDir.mkdirs()
            }

            val srcFile = File(apkPath)
            val dstFile = File(privateDir, "$packageName.apk")
            val tmpFile = File(privateDir, "$packageName.apk.tmp")

            srcFile.inputStream().use { input ->
                FileOutputStream(tmpFile).use { output ->
                    input.copyTo(output)
                }
            }

            if (dstFile.exists()) dstFile.delete()

            if (tmpFile.renameTo(dstFile)) {
                try {
                    dstFile.setReadOnly()
                } catch (_: Exception) {}
                Log.i(TAG, "Successfully installed internal extension: $packageName to ${dstFile.absolutePath}")
                true
            } else {
                tmpFile.delete()
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to install source internally: ${e.message}", e)
            false
        }
    }

    private fun uninstallSourceInternal(context: Context, packageName: String, isAnime: Boolean): Boolean {
        return try {
            val dirName = if (isAnime) "exts" else "exts_manga"
            val privateDir = File(context.filesDir, dirName)
            val apkFile = File(privateDir, "$packageName.apk")
            if (apkFile.exists()) {
                apkFile.delete()
            }
            val iconFile = File(context.cacheDir, "${packageName}_icon.png")
            if (iconFile.exists()) {
                iconFile.delete()
            }
            Log.i(TAG, "Successfully uninstalled internal extension: $packageName")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to uninstall source internally: ${e.message}", e)
            false
        }
    }

    private class ChildFirstClassLoader(
        dexPath: String,
        optimizedDirectory: String?,
        librarySearchPath: String?,
        parent: ClassLoader
    ) : DexClassLoader(dexPath, optimizedDirectory, librarySearchPath, parent) {

        private val systemClassLoader: ClassLoader? = getSystemClassLoader()

        private fun shouldDelegateToParent(name: String?): Boolean {
            if (name == null) return false
            return name.startsWith("androidx.")
        }

        override fun loadClass(name: String?, resolve: Boolean): Class<*> {
            var c = findLoadedClass(name)

            if (c == null && systemClassLoader != null) {
                try {
                    c = systemClassLoader.loadClass(name)
                } catch (_: ClassNotFoundException) {}
            }

            if (c == null && shouldDelegateToParent(name)) {
                try {
                    c = parent.loadClass(name)
                } catch (_: ClassNotFoundException) {}
            }

            if (c == null) {
                try {
                    c = findClass(name)
                } catch (_: ClassNotFoundException) {
                    c = super.loadClass(name, resolve)
                }
            }

            if (resolve) {
                resolveClass(c)
            }

            return c
        }
    }
}
