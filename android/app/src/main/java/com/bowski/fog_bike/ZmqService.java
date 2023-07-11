package com.bowski.fog_bike;

import android.util.Log;

import androidx.annotation.NonNull;

import org.zeromq.SocketType;
import org.zeromq.ZContext;
import org.zeromq.ZFrame;
import org.zeromq.ZMQ;
import org.zeromq.ZMonitor;
import org.zeromq.ZMsg;

import java.io.IOException;
import java.lang.reflect.Array;
import java.nio.charset.Charset;
import java.util.ArrayList;
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
	private static final int MAX_RETRY_COUNT = 10;

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
		Log.i(TAG, "Added coordinate to queue");
		coordinates.add(event);
	}

		public interface CoordinateResponseHandler {
		/**
		 * Handles the propagation of the Coordinate Response to Flutter.
		 *
		 *
		 * @param coordinates An array of {@link Coordinate}s.
		 */
		void messageFlutter(@NonNull Coordinate[] coordinates);
	}

	private CoordinateResponseHandler flutterHandler;

	public synchronized void setFlutterHandler(CoordinateResponseHandler handler) {
		Log.i(TAG, "Added Flutter handler");
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
		Log.d(TAG, "Stopping socket...");
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
			long delay = (long) (((double)RETRY_INITIAL_DELAY_MS + (double)Random.Default.nextLong(RETRY_RANDOM_RANGE_MS)) * Math.pow(2,count));
			Log.d(TAG, "Sleeping for " + delay + "ms.");
			Thread.sleep(delay);
		}catch(InterruptedException e){
			Log.e(TAG, "Connection retry delay interrupted");
		}
	}

	//This could be killed when disconnected and rerun when connected to save us the polling but ¯\_(ツ)_/¯
	private void runMainLoop(){
		Log.i(TAG, "Running main Loop");
		infinite:
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
						Log.d(TAG, "Message not sent, retry nr." + sendRetries);
						waitForRetry(sendRetries++);
						if(sendRetries > MAX_RETRY_COUNT)
							break infinite;
					}
				}

				ZMsg response = ZMsg.recvMsg(socket);
				if (response != null) {
					Log.i( TAG,"Coordinate sent!");
					ArrayList<Coordinate> responseCoordinates = new ArrayList<Coordinate>();
					for(ZFrame frame : response){
						Coordinate coordinate = Coordinate.fromBytes(frame.getData());
						//we only need to notify the frontend if there is danger
						if(coordinate.getType() != Coordinate.Type.SMOOTH){
							responseCoordinates.add(coordinate);
						}
					}
					Log.i( TAG,"Got response with " + responseCoordinates.size() + " coordinates!");
					coordinates.remove();
					retryCount = 0;

					// we don't need to send nothing
					if(responseCoordinates.size() > 0)
						flutterHandler.messageFlutter(responseCoordinates.toArray(new Coordinate[0]));


				} else if (response == null) {
					Log.d(TAG, "No response, resending, retry nr." + retryCount);
					waitForRetry(retryCount++);
					if(retryCount > MAX_RETRY_COUNT)
						break infinite;
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
		Log.e(TAG, "Closing mainloop");
	}
}