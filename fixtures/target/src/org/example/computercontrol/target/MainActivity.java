package org.example.computercontrol.target;

import android.app.Activity;
import android.os.Bundle;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.TextView;

/** Controlled target: one observable counter, no external effects or permissions. */
public final class MainActivity extends Activity {
    private int count;
    private TextView result;

    @Override
    public void onCreate(Bundle saved) {
        super.onCreate(saved);
        count = saved == null ? 0 : saved.getInt("count");
        LinearLayout content = new LinearLayout(this);
        content.setOrientation(LinearLayout.VERTICAL);
        result = new TextView(this);
        result.setTextSize(24);
        update();
        content.addView(result);
        Button increment = new Button(this);
        increment.setText("Increment");
        increment.setContentDescription("Fixture increment");
        increment.setOnClickListener(v -> { count++; update(); });
        content.addView(increment);
        setContentView(content);
    }

    private void update() { result.setText("Count: " + count); }

    @Override
    public void onSaveInstanceState(Bundle state) {
        state.putInt("count", count);
        super.onSaveInstanceState(state);
    }
}
