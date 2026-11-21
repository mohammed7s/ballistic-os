package org.example.computercontrol.assistant;

import android.Manifest;
import android.app.Activity;
import android.app.AppInteractionAttribution;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Intent;
import android.content.IntentSender;
import android.content.pm.PackageManager;
import android.graphics.Rect;
import android.media.Image;
import android.os.Bundle;
import android.os.OutcomeReceiver;
import android.provider.Settings;
import android.util.Log;
import android.view.accessibility.AccessibilityNodeInfo;
import android.view.accessibility.AccessibilityWindowInfo;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

import com.android.extensions.computercontrol.ComputerControlExtensions;
import com.android.extensions.computercontrol.ComputerControlSession;

import java.util.List;

/** Ordinary APK fixture. It never grants itself permissions, role, owner gates or consent. */
public final class MainActivity extends Activity {
    private static final String TARGET = "org.example.computercontrol.target";
    private static final String CHANNEL = "fixture-control";
    private static final String TAG = "OrdinaryControlFixture";
    private TextView output;
    private ComputerControlSession session;
    private boolean pending;
    private boolean destroyed;
    private long generation;

    @Override
    public void onCreate(Bundle state) {
        super.onCreate(state);
        LinearLayout content = new LinearLayout(this);
        content.setOrientation(LinearLayout.VERTICAL);
        ScrollView scroll = new ScrollView(this);
        scroll.addView(content);
        setContentView(scroll);
        output = new TextView(this);
        content.addView(output);
        button(content, "Default assistant settings", () -> startActivity(
                new Intent(Settings.ACTION_VOICE_INPUT_SETTINGS)));
        button(content, "Allow notifications", () -> requestPermissions(
                new String[]{Manifest.permission.POST_NOTIFICATIONS}, 1));
        button(content, "Request target session", this::requestSession);
        button(content, "Observe target", this::observe);
        button(content, "Tap target increment", this::tapIncrement);
        button(content, "Stop", this::stop);
        status("Extension version " + ComputerControlExtensions.getVersion()
                + "; ACCESS permission=" + (checkSelfPermission(
                    "android.permission.ACCESS_COMPUTER_CONTROL") == PackageManager.PERMISSION_GRANTED)
                + ". Authorize Screen automation in system Settings before requesting.");
    }

    private void button(LinearLayout parent, String title, Runnable action) {
        Button button = new Button(this);
        button.setText(title);
        button.setOnClickListener(v -> {
            try { action.run(); } catch (RuntimeException | LinkageError e) {
                status(e.getClass().getSimpleName() + ": " + e.getMessage());
            }
        });
        parent.addView(button);
    }

    private void status(String message) {
        Log.i(TAG, message);
        if (!destroyed) output.append(message + "\n");
    }

    private void requestSession() {
        if (pending || session != null) { status("A request/session already exists"); return; }
        if (ComputerControlExtensions.getVersion() < 5) {
            status("Version 5 is required"); return;
        }
        ComputerControlExtensions extensions = ComputerControlExtensions.getInstance(this, 5);
        if (extensions == null) { status("Extension unavailable"); return; }
        NotificationManager notifications = getSystemService(NotificationManager.class);
        notifications.createNotificationChannel(new NotificationChannel(
                CHANNEL, "Controlled app test", NotificationManager.IMPORTANCE_DEFAULT));
        PendingIntent show = PendingIntent.getActivity(this, 0,
                new Intent(this, MainActivity.class), PendingIntent.FLAG_IMMUTABLE);
        Notification notification = new Notification.Builder(this, CHANNEL)
                .setSmallIcon(android.R.drawable.ic_menu_view)
                .setContentTitle("Controlled app test")
                .setContentText("Screen automation is active. Open this app to stop.")
                .setContentIntent(show).setOngoing(true).setRequestPromotedOngoing(true).build();
        ComputerControlSession.Params params = new ComputerControlSession.Params.Builder(this)
                .setName("ordinary-fixture").setTargetPackageNames(List.of(TARGET))
                .setAppInteractionAttribution(new AppInteractionAttribution.Builder(
                        AppInteractionAttribution.INTERACTION_TYPE_USER_QUERY).build())
                .setNotificationParams(new ComputerControlSession.NotificationParams.Builder(
                        notification, 17).build()).build();
        pending = true;
        final long request = ++generation;
        try {
            extensions.requestSession(params, getMainExecutor(), new ComputerControlSession.Callback() {
                @Override public void onSessionPending(IntentSender sender) {
                    if (destroyed || request != generation) return;
                    status("System target consent required");
                    try { startIntentSenderForResult(sender, 2, null, 0, 0, 0); }
                    catch (IntentSender.SendIntentException e) { pending = false; status(e.toString()); }
                }
                @Override public void onSessionCreated(ComputerControlSession created) {
                    if (destroyed || request != generation) { created.close(); return; }
                    pending = false;
                    session = created;
                    created.setLifecycleCallback(getMainExecutor(), new ComputerControlSession.LifecycleCallback() {
                        @Override public void onActive() { status("Session active"); }
                        @Override public void onBlocked(int reason, String target) {
                            status("Blocked: " + reason + " " + target);
                        }
                        @Override public void onClosed(int reason) {
                            if (session == created) session = null;
                            status("Session closed: " + reason);
                        }
                    });
                    try {
                        created.launchApplication(TARGET);
                        status("Session created; controlled target launched");
                    } catch (RuntimeException e) {
                        created.close(); session = null; status("Launch failed: " + e);
                    }
                }
                @Override public void onSessionCreationFailed(int reason) {
                    if (request != generation) return;
                    pending = false; status("Session denied/failed: " + reason);
                }
                @Override public void onSessionClosed() {
                    if (request != generation) return;
                    pending = false; session = null; status("Closed");
                }
            });
        } catch (RuntimeException | LinkageError e) { pending = false; throw e; }
    }

    private void observe() {
        if (session == null) { status("No session"); return; }
        for (AccessibilityWindowInfo window : session.getAccessibilityWindows()) {
            describe(window.getRoot());
        }
        session.requestScreenshot(getMainExecutor(),
                new OutcomeReceiver<Image, ComputerControlSession.ScreenshotException>() {
                    @Override public void onResult(Image image) {
                        try { status("Screenshot " + image.getWidth() + "x" + image.getHeight()); }
                        finally { image.close(); }
                    }
                    @Override public void onError(ComputerControlSession.ScreenshotException error) {
                        status("Screenshot error: " + error.getErrorCode());
                    }
                }, null);
    }

    private void describe(AccessibilityNodeInfo node) {
        if (node == null || !TARGET.contentEquals(node.getPackageName() == null ? "" : node.getPackageName())) return;
        if (node.getText() != null) status("Target: " + node.getText());
        for (int i = 0; i < node.getChildCount(); i++) describe(node.getChild(i));
    }

    private void tapIncrement() {
        if (session == null) { status("No session"); return; }
        for (AccessibilityWindowInfo window : session.getAccessibilityWindows()) {
            Rect bounds = findIncrement(window.getRoot());
            if (bounds != null) {
                session.tap(bounds.centerX(), bounds.centerY());
                status("Tap sent; Observe target to verify the counter changed");
                return;
            }
        }
        status("Controlled target button is not visible in the session tree");
    }

    private Rect findIncrement(AccessibilityNodeInfo node) {
        if (node == null || !TARGET.contentEquals(node.getPackageName() == null ? "" : node.getPackageName())) return null;
        if ("Fixture increment".contentEquals(node.getContentDescription() == null ? "" : node.getContentDescription())) {
            Rect bounds = new Rect(); node.getBoundsInScreen(bounds); return bounds;
        }
        for (int i = 0; i < node.getChildCount(); i++) {
            Rect bounds = findIncrement(node.getChild(i)); if (bounds != null) return bounds;
        }
        return null;
    }

    private void stop() {
        ++generation;
        pending = false;
        if (session != null) { session.close(); session = null; status("Stop requested"); }
    }

    @Override protected void onDestroy() {
        destroyed = true;
        stop();
        super.onDestroy();
    }
}
