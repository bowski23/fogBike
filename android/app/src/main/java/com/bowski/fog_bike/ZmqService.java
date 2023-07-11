package com.bowski.fog_bike;

import android.util.Log;

import androidx.annotation.NonNull;

import org.zeromq.SocketType;
import org.zeromq.ZContext;
import org.zeromq.ZMQ;
import org.zeromq.ZMonitor;
import org.zeromq.ZMsg;

import java.io.IOException;
import java.nio.charset.Charset;
import java.util.concurrent.ConcurrentLinkedQueue;

import classes.Coordinate;
import io.flutter.plugin.common.MethodCall;
import kotlin.random.Random;

public class ZmqService {
	private static final int RECV_TIMEOUT = 500;
	private static final int SEND_TIMEOUT = 200;
	private static final String SERVER_ADDRESS = "tcp://34.142.26.27:8080";
	private static final long RETRY_INITIAL_DELAY_MS = 100;
	private static final long RETRY_RANDOM_RANGE_MS = 20;
	private static final long SCHEDULE = 200;
	private static final int MAX_RETRY_COUNT = 7;

	private static final String TAG = "ZmqService";

	private ConcurrentLinkedQueue<Coordinate> coordinates = new ConcurrentLinkedQueue<Coordinate>();
	private ZContext context = new ZContext();;
	private ZMQ.Socket socket;
	private Monitor monitor;
	private Thread mainServiceThread;
	private int retryCount = 0;

	private boolean isConnected = false;

	private static volatile ZmqService instance;

	private ZmqService() {
	}

	public static ZmqService getInstance(){
		ZmqService result = instance;
		if (result != null) {
			return result;
		}
		synchronized(ZmqService.class) {
			if (instance == null) {
				instance = new ZmqService();
			}
			return instance;
		}
	}

	public synchronized void addCoordinate(Coordinate event) {
		coordinates.add(event);
	}

		public interface CoordinateResponseHandler {
		/**
		 * Handles the propagation of the Coordinate Response to Flutter.
		 *
		 *
		 * @param coordinate A {@link MethodCall}.
		 */
		void messageFlutter(@NonNull Coordinate coordinate);
	}

	private CoordinateResponseHandler flutterHandler;

	public synchronized void setFlutterHandler(CoordinateResponseHandler handler) {
		flutterHandler = handler;
	}

	private class Monitor extends Thread {
		private boolean isAlive = true;

		public void kill(){
			isAlive = false;
		}

		@Override
		public void run() {
			ZMonitor monitor = new ZMonitor(context,socket);
			monitor.add(ZMonitor.Event.CONNECTED, ZMonitor.Event.DISCONNECTED);
			monitor.start();
			while (isAlive) {
				ZMonitor.ZEvent event = monitor.nextEvent();

				switch(event.type){
					case CONNECTED:
						isConnected = true;
						Log.d(TAG, "Connected to Server!");
						break;
					case DISCONNECTED:
						isConnected = false;
						Log.d(TAG, "Disconnected from Server!");
						break;
					default:
						Log.d(TAG, "Monitor unhandled event");
						break;
				}
			}

			try {
				monitor.close();
			} catch (IOException e) {
				throw new RuntimeException(e);
			}
		}
	}

	public void startSocket() {
		Log.d(TAG,"Starting...");

		socket = context.createSocket(SocketType.REQ);
		socket.setReceiveTimeOut(RECV_TIMEOUT);
		socket.setSendTimeOut(SEND_TIMEOUT);
		socket.setReqRelaxed(true);
		socket.setLinger(0);
		monitor = new Monitor();
		monitor.start();
		socket.connect(SERVER_ADDRESS);

		runMainLoop();
	}

	public void stopSocket(){
		socket.close();
		monitor.kill();
	}

	void waitForRetry(int count){
		if(count > MAX_RETRY_COUNT){
			Log.e(TAG, "Max connections retries reached, shutting down server...");
			stopSocket();
			return;
		}

		try{
			//Randomized spread so that not all connection retries happen at roughly the same time
			Thread.sleep((long) ((RETRY_INITIAL_DELAY_MS + Random.Default.nextLong(RETRY_RANDOM_RANGE_MS)) * Math.pow(2,count)));
		}catch(InterruptedException e){
			Log.e(TAG, "Connection retry delay interrupted");
		}
	}

	//This could be killed when disconnected and rerun when connected to save us the polling but ¯\_(ツ)_/¯
	private void runMainLoop(){
		Log.i(TAG, "Running main Loop");
		while (true) {
			if (!coordinates.isEmpty()) {
				Log.i( TAG,"Trying to send Location...");
				ZMsg request = new ZMsg();
				Coordinate top = coordinates.peek();
				request.add(top.toBytes());

				boolean isMessageSent = false;
				int sendRetries = 0;
				while(!isMessageSent){
					isMessageSent = request.send(socket);

					if(!isMessageSent){
						waitForRetry(sendRetries++);
						if(sendRetries > MAX_RETRY_COUNT)
							return;
					}
				}

				ZMsg response = ZMsg.recvMsg(socket);
				if (response != null) {
					Log.i( TAG,"Coordinate sent!");
					String type = response.removeFirst().getString(Charset.defaultCharset());
					Log.i( TAG,"Got response" + type);
					Coordinate.Type dangerLevel;
					switch (type.toUpperCase()){
						case "HIGH":
							dangerLevel = Coordinate.Type.HIGH;
							break;
						case "MEDIUM":
							dangerLevel = Coordinate.Type.MEDIUM;
							break;
						case "LOW":
							dangerLevel = Coordinate.Type.LOW;
							break;
						default:
							dangerLevel = Coordinate.Type.SMOOTH;
					}
					Coordinate coordinate = coordinates.remove();
					retryCount = 0;
					//we only need to notify the frontend if there is danger or traffic
					if(dangerLevel != Coordinate.Type.SMOOTH){
						coordinate.setType(dangerLevel);
						flutterHandler.messageFlutter(coordinate);
					}

				} else if (response == null) {
					waitForRetry(retryCount++);
					if(retryCount > MAX_RETRY_COUNT)
						return;
					continue;
				}
			}

			if (isConnected && coordinates.isEmpty()) {
				try {
					Log.i(TAG,"Send cycle finished. Queue empty. Polling again in " + SCHEDULE + "ms.");
					Thread.sleep(SCHEDULE);
				} catch (InterruptedException e) {
					Log.e(TAG,"Poll sleep interrupted: " + e.toString());
				}
			}
		}
	}
}