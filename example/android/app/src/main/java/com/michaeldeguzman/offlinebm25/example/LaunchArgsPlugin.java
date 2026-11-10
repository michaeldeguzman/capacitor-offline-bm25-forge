package com.michaeldeguzman.offlinebm25.example;

import com.getcapacitor.JSArray;
import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;
import java.io.File;
import java.util.Arrays;

/**
 * Example app only. Hands the "validate" intent extra to the web page, so a validation run can
 * be started with: adb shell am start -n <package>/.MainActivity --es validate p1
 */
@CapacitorPlugin(name = "LaunchArgs")
public class LaunchArgsPlugin extends Plugin {

    @PluginMethod
    public void get(PluginCall call) {
        JSObject ret = new JSObject();
        String value = getActivity().getIntent().getStringExtra("validate");
        if (value != null) {
            ret.put("validate", value);
        }
        call.resolve(ret);
    }

    /** Sizes in bytes of the plugin's collection files, for the timing report. */
    @PluginMethod
    public void fileSizes(PluginCall call) {
        File dir = new File(getContext().getFilesDir(), "offlinebm25");
        File[] files = dir.listFiles();
        if (files == null) {
            files = new File[0];
        }
        Arrays.sort(files);
        JSArray list = new JSArray();
        for (File f : files) {
            JSObject o = new JSObject();
            o.put("name", f.getName());
            o.put("bytes", f.length());
            list.put(o);
        }
        JSObject ret = new JSObject();
        ret.put("files", list);
        call.resolve(ret);
    }
}
