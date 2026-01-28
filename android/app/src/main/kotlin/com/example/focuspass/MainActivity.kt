package com.example.focuspass

import android.app.Activity
import android.app.ActivityManager
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.view.WindowManager
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val APP_BLOCKER_CHANNEL = "com.focuspass.app_blocker"
    private val APP_LAUNCHER_CHANNEL = "com.focuspass.app_launcher"
    
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Set up app blocker method channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, APP_BLOCKER_CHANNEL).setMethodCallHandler {
            call, result ->
            when (call.method) {
                "showBlockingOverlay" -> {
                    val appName = call.argument<String>("appName") ?: "app"
                    val message = call.argument<String>("message") ?: "Time limit reached"
                    showBlockingOverlay(appName, message)
                    result.success(null)
                }
                "showEducationalBlockingOverlay" -> {
                    val appName = call.argument<String>("appName") ?: "app"
                    val title = call.argument<String>("title") ?: "Tasks Required"
                    val message = call.argument<String>("message") ?: "Complete educational tasks first"
                    val earnableTime = call.argument<String>("earnableTime") ?: "15 minutes"
                    val actionText = call.argument<String>("actionText") ?: "Complete Tasks"
                    showEducationalBlockingOverlay(appName, title, message, earnableTime, actionText)
                    result.success(null)
                }
                "showTimeExceededBlockingOverlay" -> {
                    val appName = call.argument<String>("appName") ?: "app"
                    val title = call.argument<String>("title") ?: "Time Limit Reached"
                    val message = call.argument<String>("message") ?: "Daily time limit exceeded"
                    val actionText = call.argument<String>("actionText") ?: "Complete Tasks for More Time"
                    showTimeExceededBlockingOverlay(appName, title, message, actionText)
                    result.success(null)
                }
                "showFinalNotificationOverlay" -> {
                    val title = call.argument<String>("title") ?: "Screen Time Limit Reached"
                    val message = call.argument<String>("message") ?: "You have run out of screen time for the day."
                    showFinalNotificationOverlay(title, message)
                    result.success(null)
                }
                "openUsageStatsSettings" -> {
                    openUsageStatsSettings()
                    result.success(null)
                }
                "closeForegroundApp" -> {
                    navigateHome()
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // Set up app launcher method channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, APP_LAUNCHER_CHANNEL).setMethodCallHandler {
            call, result ->
            when (call.method) {
                "bringToForeground" -> {
                    bringAppToForeground()
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
    
    private fun showBlockingOverlay(appName: String, message: String) {
        runOnUiThread {
            // Create and show blocking dialog
            val intent = Intent(this, BlockingOverlayActivity::class.java).apply {
                putExtra("appName", appName)
                putExtra("title", "Time Limit Reached")
                putExtra("message", message)
                putExtra("actionText", "Complete Tasks for More Time")
                putExtra("overlayType", "time_exceeded")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            startActivity(intent)
        }
    }
    
    private fun showEducationalBlockingOverlay(
        appName: String, 
        title: String, 
        message: String, 
        earnableTime: String, 
        actionText: String
    ) {
        runOnUiThread {
            val intent = Intent(this, BlockingOverlayActivity::class.java).apply {
                putExtra("appName", appName)
                putExtra("title", title)
                putExtra("message", message)
                putExtra("earnableTime", earnableTime)
                putExtra("actionText", actionText)
                putExtra("overlayType", "educational_tasks")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            startActivity(intent)
        }
    }
    
    private fun showTimeExceededBlockingOverlay(
        appName: String, 
        title: String, 
        message: String, 
        actionText: String
    ) {
        runOnUiThread {
            val intent = Intent(this, BlockingOverlayActivity::class.java).apply {
                putExtra("appName", appName)
                putExtra("title", title)
                putExtra("message", message)
                putExtra("actionText", actionText)
                putExtra("overlayType", "time_exceeded")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            startActivity(intent)
        }
    }
    
    private fun showFinalNotificationOverlay(title: String, message: String) {
        runOnUiThread {
            val intent = Intent(this, BlockingOverlayActivity::class.java).apply {
                putExtra("title", title)
                putExtra("message", message)
                putExtra("overlayType", "final_notification")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            startActivity(intent)
        }
    }
    
    private fun openUsageStatsSettings() {
        val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        startActivity(intent)
    }
    
    private fun bringAppToForeground() {
        // Bring FocusPass to foreground
        val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val appTasks = activityManager.appTasks
        
        for (task in appTasks) {
            val taskInfo = task.taskInfo
            if (taskInfo.baseActivity?.packageName == packageName) {
                task.moveToFront()
                return
            }
        }
        
        // If not found in tasks, launch main activity
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        startActivity(intent)
    }

    private fun navigateHome() {
        // Navigate user to home screen, effectively hiding the current foreground app
        val intent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        startActivity(intent)
    }
}
