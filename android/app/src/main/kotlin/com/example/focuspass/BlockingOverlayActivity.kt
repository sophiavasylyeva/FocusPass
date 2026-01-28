package com.example.focuspass

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.EditText
import android.widget.TextView
import androidx.activity.OnBackPressedCallback
import androidx.appcompat.app.AppCompatActivity

class BlockingOverlayActivity : AppCompatActivity() {
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Make this activity appear above other apps
        window.setFlags(
            WindowManager.LayoutParams.FLAG_FULLSCREEN,
            WindowManager.LayoutParams.FLAG_FULLSCREEN
        )
        
        // Set the layout based on overlay type
        val overlayType = intent.getStringExtra("overlayType") ?: "time_exceeded"
        
        when (overlayType) {
            "educational_tasks" -> setupEducationalTasksOverlay()
            "time_exceeded" -> setupTimeExceededOverlay()
            "final_notification" -> setupFinalNotificationOverlay()
            else -> setupTimeExceededOverlay()
        }
        
        // Handle back press with new API
        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() {
                // Prevent back button from closing the overlay
                // User must interact with the buttons
            }
        })
    }
    
    private fun setupEducationalTasksOverlay() {
        setContentView(R.layout.activity_educational_blocking_overlay)
        
        val appName = intent.getStringExtra("appName") ?: "app"
        val title = intent.getStringExtra("title") ?: "Complete Educational Tasks First!"
        val message = intent.getStringExtra("message") ?: "You need to complete educational tasks before accessing this app."
        val earnableTime = intent.getStringExtra("earnableTime") ?: "15 minutes"
        val actionText = intent.getStringExtra("actionText") ?: "Complete Tasks"
        
        findViewById<TextView>(R.id.titleText).text = title
        findViewById<TextView>(R.id.messageText).text = message
        findViewById<TextView>(R.id.earnableTimeText).text = "Complete tasks to earn $earnableTime of screen time!"
        
        val actionButton = findViewById<Button>(R.id.actionButton)
        actionButton.text = actionText
        actionButton.setOnClickListener {
            openFocusPassApp()
        }
        
        val laterButton = findViewById<Button>(R.id.laterButton)
        laterButton.setOnClickListener {
            finish()
        }
    }
    
    private fun setupTimeExceededOverlay() {
        setContentView(R.layout.activity_time_exceeded_overlay)
        
        val appName = intent.getStringExtra("appName") ?: "app"
        val title = intent.getStringExtra("title") ?: "Time Limit Reached"
        val message = intent.getStringExtra("message") ?: "You've reached your daily time limit for this app."
        val actionText = intent.getStringExtra("actionText") ?: "Complete Tasks for More Time"
        
        findViewById<TextView>(R.id.titleText).text = title
        findViewById<TextView>(R.id.messageText).text = message
        
        val actionButton = findViewById<Button>(R.id.actionButton)
        actionButton.text = actionText
        actionButton.setOnClickListener {
            openFocusPassApp()
        }
        
        val closeButton = findViewById<Button>(R.id.closeButton)
        closeButton.setOnClickListener {
            // Exit the application when close/exit button is pressed
            finish()
        }
    }
    
    private fun setupFinalNotificationOverlay() {
        setContentView(R.layout.activity_final_notification_overlay)

        val title = intent.getStringExtra("title") ?: "Screen Time Limit Reached"
        val message = intent.getStringExtra("message") ?: "You have run out of screen time for the day."

        findViewById<TextView>(R.id.titleText).text = title
        findViewById<TextView>(R.id.messageText).text = message

        val pinInput = findViewById<EditText>(R.id.pinInput)
        val overrideButton = findViewById<Button>(R.id.overrideButton)

        overrideButton.setOnClickListener {
            val enteredPin = pinInput.text.toString()
            // Here you would typically verify the PIN against the one stored for the parent.
            // For this example, we'll just check if it's 5 digits long.
            if (enteredPin.length == 5) {
                finish() // Close the overlay
            } else {
                pinInput.error = "Invalid PIN"
            }
        }

        val exitButton = findViewById<Button>(R.id.exitButton)
        exitButton.setOnClickListener {
            finish() // Exit the overlay and close the blocked app
        }
    }
    
    private fun openFocusPassApp() {
        // Launch FocusPass main activity
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        startActivity(intent)
        finish()
    }
    
    override fun onPause() {
        super.onPause()
        // Don't allow the overlay to be paused/hidden
        finish()
    }
}
