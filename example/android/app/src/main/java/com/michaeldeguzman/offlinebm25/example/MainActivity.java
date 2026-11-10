package com.michaeldeguzman.offlinebm25.example;

import android.os.Bundle;
import com.getcapacitor.BridgeActivity;

public class MainActivity extends BridgeActivity {
    @Override
    public void onCreate(Bundle savedInstanceState) {
        registerPlugin(LaunchArgsPlugin.class);
        super.onCreate(savedInstanceState);
    }
}
