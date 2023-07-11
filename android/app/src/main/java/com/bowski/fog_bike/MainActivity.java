package com.bowski.fog_bike;

import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import androidx.annotation.NonNull;

import classes.Coordinate;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugins.GeneratedPluginRegistrant;

public class MainActivity extends FlutterActivity {

    private static final String CHANNEL = "fog_bike.bowski.com/communication";
    private MethodChannel channel;

    private Thread backgroundThread;
    private int counter = 0;

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine);
        BinaryMessenger messenger = flutterEngine.getDartExecutor().getBinaryMessenger();
        channel = new MethodChannel(
                messenger,
                CHANNEL);
        channel.setMethodCallHandler(this::onMethodCall);
    }

    public void onMethodCall(MethodCall call, MethodChannel.Result result){
        switch(call.method) {
            case "initZmq":
                Log.d("JavaActivity", "onMethodCall: initZmq called");
                try{
                    backgroundThread = new Thread(() -> {
                        Log.d("JavaActivity", "onMethodCall: initZmq called, running on background thread");
                        runZmq();
                    });
                    backgroundThread.start();
                    result.success(null);
                    Log.d("JavaActivity", "onMethodCall: initZmq appears to run successfully");

                }catch(Exception e){
                    Log.e("JavaActivity", "onMethodCall: initZmq failed");
                    result.error("zmq-error",e.toString(),null);
                }
                break;
            case "queueMsg":
                double lat = call.argument("latitude");
                double lon = call.argument("longitude");
                int lvl = call.argument("level");
                Log.i("JavaActivity", "onMethodCall: queueMsg: " + lat + " " + lon + " " + lvl);
                Coordinate.Type type;
                type = Coordinate.Type.values()[lvl];
                ZmqService.getInstance().addCoordinate(
                        new Coordinate(lat,lon,type));
                break;
            default:
                result.notImplemented();
        }
    }

    public void runZmq(){
        ZmqService instance = ZmqService.getInstance();
        instance.setFlutterHandler(this::messageFlutter);
        instance.startSocket();
    }

    private static String toIntermediaryString(Coordinate coordinate){
        int lvl;
        switch (coordinate.getType()){
            case SMOOTH:
            case TRAFFIC:
                lvl = 0;
            default:
                lvl = coordinate.getType().ordinal();
        }
        return "{"+
                "\"latitude\":" + coordinate.getLatitude() +
                ", \"longitude\":" + coordinate.getLongitude() +
                ", \"level\":" + lvl + "}";
    }

    private static String toJsonArray(Coordinate[] coordinates){
        String json = "{\"coordinates\": [";
        boolean isFirst = true;
        for(Coordinate coordinate : coordinates){
            if(isFirst) {
                isFirst = false;
            } else {
                json += ", ";
            }
            json += toIntermediaryString(coordinate);
        }
        json += "]}";
        return json;
    }
    public void messageFlutter(Coordinate[] coordinates){
        new Handler(Looper.getMainLooper()).post(() -> {
            Log.d("JavaActivity", "messaging Flutter");
            channel.invokeMethod("onResponse", toJsonArray(coordinates));
        });
    }
}
