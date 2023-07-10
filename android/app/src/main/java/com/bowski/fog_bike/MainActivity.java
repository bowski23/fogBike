package com.bowski.fog_bike;

import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import androidx.annotation.NonNull;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugins.GeneratedPluginRegistrant;

import org.zeromq.SocketType;
import org.zeromq.ZMQ;
import org.zeromq.ZContext;
import org.zeromq.ZSocket;

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
                break;
            case "pollResponse":
                Log.i("JavaActivity", "onMethodCall: pollResponse");
                result.success(counter);
                break;
            default:
                result.notImplemented();
        }
    }

    public void runZmq(){
        try {
            ZContext context = new ZContext();
            ZSocket socket = new ZSocket(SocketType.REQ);
            socket.connect("tcp://192.168.178.20:8080");
            while (true) {
                Thread.sleep(200);
                Log.i("JavaActivity", "Zmq - sending msg nr." + counter);
                socket.sendStringUtf8("Hello Nr. " + counter + "!");
                counter++;
                String str = socket.receiveStringUtf8();
                Log.i("JavaActivity", "Zmq - received:" + str);
                messageFlutter();
            }
        } catch (InterruptedException e) {
            throw new RuntimeException(e);
        }
    }

    public void messageFlutter(){
        new Handler(Looper.getMainLooper()).post(new Runnable() {
            @Override
            public void run() {
                Log.d("JavaActivity", "messaging Flutter");
                channel.invokeMethod("onResponse",counter);
            }
        });
    }
}
