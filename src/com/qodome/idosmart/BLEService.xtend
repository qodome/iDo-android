package com.qodome.idosmart

import android.app.IntentService
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattService
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.content.Intent
import android.os.Environment
import android.os.ParcelUuid
import android.util.Log

import java.io.File
import java.io.FileNotFoundException
import java.io.FileOutputStream
import java.io.IOException
import java.io.OutputStreamWriter
import java.util.ArrayList
import java.util.List
import java.util.UUID
import java.util.Map
import java.util.HashMap
import android.content.BroadcastReceiver
import android.content.Context
import android.content.IntentFilter
import android.bluetooth.BluetoothGattDescriptor
import java.util.Calendar
import java.util.TimeZone
import java.lang.StringBuilder
import android.app.Notification
import org.json.JSONArray
import com.google.common.io.CharStreams
import java.io.InputStreamReader
import java.io.InputStream
import com.google.common.base.Charsets
import java.io.FileInputStream
import java.util.concurrent.locks.Lock
import java.util.concurrent.locks.ReentrantLock
import android.preference.PreferenceManager
import android.media.RingtoneManager
import android.media.Ringtone
import android.app.PendingIntent

class BLEService extends IntentService {
	val static public final int HISTORY_DUMP_PERIOD_COUNT = 12
	val static public final int HISTORY_STATS_SECONDS = 300
	
	var BluetoothManager mBluetoothManager
    var BluetoothAdapter mBluetoothAdapter
    static public var BluetoothDevice mDevice = null
    static public var BluetoothGatt mGatt = null
    var String mConnStatus = "transit"
    static public var Map<String, BluetoothDevice> mScanDevMap
    static public var List<String> mScanDevNameList
    static public var List<String> mScanDevAddrList
    static public var DeviceDetailActivity ddActivity = null
    static public var OADService oadService = null
    var String folderName
    var boolean mScanStarted = false
    var boolean mTriggerMonitorStart = false
    var long mPeriodStart = 0
    var double mPeriodTempStart = 0.0
    var double mPeriodTempMax = 0.0
    var double mPeriodTempMin = 0.0
    var double mPeriodTempLast = 0.0
    var boolean mPeriodTempValid = false
    var boolean mServiceRunning = false
    var String mLogFileName
    var JSONArray mTempJson = null
    var Lock mLock
    var String forceConnectAddress = null
    var Ringtone r;
    var UUID[] scanUUID = #[UUID.fromString(GATTConstants.BLE_HEALTH_THERMOMETER)]
    static var boolean readInProgress = false
    static var int readWaitPeriod = 0
    static var List<BluetoothGattCharacteristic> readQueue
    static var Lock mReadQueueLock
    static var BluetoothGattCharacteristic mReadGattChar = null
    
    var BluetoothAdapter.LeScanCallback mLeScanCallback =
            new BluetoothAdapter.LeScanCallback() {
        override onLeScan(BluetoothDevice device, int rssi, byte[] scanRecord) {
        	mLock.lock()
        	if (!mScanDevMap.containsKey(device.getAddress())) {
        		Log.i(getString(R.string.LOGTAG), "Scan found device: " + device.getAddress())
        		mScanDevMap.put(device.getAddress(), device)
        		// Force update available list: send query by self
        		sendBroadcast(new Intent(getString(R.string.ACTION_REQ_DEV_LIST_AVAILABLE)))
        		mScanDevNameList.add(device.getName())
        		mScanDevAddrList.add(device.getAddress())
        	}        	
        	mLock.unlock()
        }
    }
	
	def updateConnectionList() {
		var p = new IPC
		p.devAddr = new ArrayList<String>()
		p.devName = new ArrayList<String>()
		if (mDevice != null) {
			p.devAddr.add(mDevice.getAddress())
			p.devName.add(mDevice.getName())
			p.devConnStatus = mConnStatus
		} else {
			p.devAddr.add("NOT_CONNECTED")
			p.devName.add("NOT_CONNECTED")
		}
		sendBroadcast(new Intent(getString(R.string.ACTION_RSP_DEV_LIST_CONNECTED)).putExtra(getString(R.string.ACTION_EXTRA), p))
	}
	
	var BroadcastReceiver mServiceActionReceiver = new BroadcastReceiver() {
		override onReceive(Context context, Intent intent) {
			if (intent.getAction().equals(getString(R.string.ACTION_REQ_DEV_LIST_AVAILABLE))) {
				if (mScanStarted == false) {
					mScanStarted = true
					mBluetoothAdapter?.startLeScan(scanUUID, mLeScanCallback)
				}
				
				mLock.lock()
				var p = new IPC
				p.devAddr = mScanDevAddrList
				p.devName = mScanDevNameList
				mLock.unlock()
				sendBroadcast(new Intent(getString(R.string.ACTION_RSP_DEV_LIST_AVAILABLE)).putExtra(getString(R.string.ACTION_EXTRA), p))
			} else if (intent.getAction().equals(getString(R.string.ACTION_REQ_DEV_LIST_CONNECTED))) {
				updateConnectionList()
			} else if (intent.getAction().equals(getString(R.string.ACTION_CONNECT_TO_DEVICE))) {
				// Disconnect with previous connection if there is any
				mGatt?.disconnect()
                mGatt?.close()
                mGatt = null
                mDevice = null
				
				var IPC p = intent.getParcelableExtra(getString(R.string.ACTION_EXTRA))
				forceConnectAddress = p.devAddr.get(0)
				connect(forceConnectAddress)
			} else if (intent.getAction().equals(getString(R.string.ACTION_DISCONNECT))) {
				Log.i(getString(R.string.LOGTAG), "disconnect!")
				mGatt?.disconnect()
                mGatt?.close()
                mGatt = null
                mDevice = null
                forceConnectAddress = null
                sendBroadcast(new Intent(getString(R.string.ACTION_REQ_DEV_LIST_AVAILABLE)))
				sendBroadcast(new Intent(getString(R.string.ACTION_REQ_DEV_LIST_CONNECTED)))
			} else if (intent.getAction().equals(getString(R.string.ACTION_STOP_SCAN))) {
				if (mScanStarted == true) {
					mScanStarted = false
					mBluetoothAdapter?.stopLeScan(mLeScanCallback)					
				}
			}
		}
	}
	
	def serviceActionIntentFilter() {
		var intentFilter = new IntentFilter()
		intentFilter.addAction(getString(R.string.ACTION_REQ_DEV_LIST_AVAILABLE))
		intentFilter.addAction(getString(R.string.ACTION_REQ_DEV_LIST_CONNECTED))
		intentFilter.addAction(getString(R.string.ACTION_CONNECT_TO_DEVICE))
		intentFilter.addAction(getString(R.string.ACTION_DISCONNECT))
		intentFilter.addAction(getString(R.string.ACTION_STOP_SCAN))
		return intentFilter
	}
	
	new() {
		super("BLEService")
	}
	
	override onStartCommand(Intent intent, int flags, int startId) {
		if (intent.hasExtra("SHUTDOWN")) {
			Log.i(getString(R.string.LOGTAG), "BLEService get shutdown request")
			mServiceRunning = false
			sendBroadcast(new Intent(getString(R.string.ACTION_STOP)))
			stopSelf()
        }
        return super.onStartCommand(intent, flags, startId)
	}
	
	override onCreate() {
    	super.onCreate()
    	
    	mServiceRunning = true
    	registerReceiver(mServiceActionReceiver, serviceActionIntentFilter())
    	    	
    	// Storage
		if (!Environment.MEDIA_MOUNTED.equals(Environment.getExternalStorageState())) {
			Log.e(getString(R.string.LOGTAG), "External storage not mounted")
	        return
	    }
		
		var reportFolder = new File(Environment.getExternalStorageDirectory().getAbsolutePath() + "/" + "iDoSmart")
		if (!reportFolder.exists()) {
			Log.i(getString(R.string.LOGTAG), "Creating missing directory iDoStatsMonitor")
			reportFolder.mkdirs()
		}
		folderName = new String(Environment.getExternalStorageDirectory().getAbsolutePath() + "/iDoSmart/")
    	
        // For API level 18 and above, get a reference to BluetoothAdapter through
        // BluetoothManager.
        mBluetoothManager = getSystemService("bluetooth") as BluetoothManager
        mBluetoothAdapter = mBluetoothManager?.getAdapter()

		mLock = new ReentrantLock()
        mScanDevMap = new HashMap<String, BluetoothDevice>()
        mScanDevNameList = new ArrayList<String>()
        mScanDevAddrList = new ArrayList<String>()
    	
    	var intentStop = new Intent(this, typeof(BLEService))
    	intentStop.putExtra("SHUTDOWN", "SHUTDOWN");
    	var intentStart = new Intent(this, MainActivity)
    	var note = new Notification.Builder(this)
        				.setContentTitle("iDoSmart is running")
         				.setContentText("Tap to open")
    	 				.setContentIntent(PendingIntent.getActivity(this, 0, intentStart, PendingIntent.FLAG_CANCEL_CURRENT))
         				.setSmallIcon(R.drawable.ido_notification)
         				.addAction(R.drawable.switch_off, "OFF", PendingIntent.getService(this, 0, intentStop, PendingIntent.FLAG_CANCEL_CURRENT))
         				.build()
        note.flags = Notification.FLAG_NO_CLEAR
    	startForeground(42, note)
    	
    	//.addAction(R.drawable.icon_small, "OPEN", PendingIntent.getActivity(this, 0, new Intent(this, MainActivity), Intent.FLAG_ACTIVITY_NEW_TASK))
    	
    	
		mTempJson = new JSONArray()
   		readQueue = new ArrayList<BluetoothGattCharacteristic>()
   		mReadQueueLock = new ReentrantLock()
		
		r = RingtoneManager.getRingtone(getApplicationContext(), RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM))
				
		Log.i(getString(R.string.LOGTAG), "BLEService created")        
    }
	
	override onDestroy() {
		unregisterReceiver(mServiceActionReceiver)
		super.onDestroy();
	}
	
	def waitMillis(int m) {
    	var endTime = System.currentTimeMillis() + m
    	
        while (System.currentTimeMillis() < endTime) {
            synchronized (this) {
                try {
                    wait(endTime - System.currentTimeMillis())
                } catch (Exception e) {
                }
            }
        }	
    }
    
    def getZoneIndependentTime() {
    	var c = Calendar.getInstance()
        var fn = new String(c.get(Calendar.YEAR) + "_" + (c.get(Calendar.MONTH) + 1) + "_" + c.get(Calendar.DAY_OF_MONTH) + ".json")
    	var sec = (c.getTimeInMillis() + c.getTimeZone().getOffset(c.getTimeInMillis())) / 1000L
    	return #[fn, sec]
    }
    
	override onHandleIntent(Intent intent) {                
    	Log.i(getString(R.string.LOGTAG), "onHandleIntent started") 	    	    	
    	var ret = getZoneIndependentTime()
    	mLogFileName = ret.get(0) as String
    	mPeriodStart = ret.get(1) as Long
    	mPeriodStart = (mPeriodStart / HISTORY_STATS_SECONDS) * HISTORY_STATS_SECONDS
    	Log.i(getString(R.string.LOGTAG), "filename: " + mLogFileName + " period: " + mPeriodStart)

    	while (mServiceRunning == true) {
    		ret = getZoneIndependentTime()
    		val timeNow = ret.get(1) as Long
    		val fnNow = ret.get(0) as String
        	if ((timeNow - mPeriodStart) >= HISTORY_STATS_SECONDS) {
        		mLock.lock()
        		if (fnNow != mLogFileName) {
        			// Dump log into mLogFileName, we are crossing middle night
        			if (mTempJson.length() > 0) {
        				dumpJsonArray(mTempJson, mLogFileName)
        				mTempJson = new JSONArray()
        			}
        			mLogFileName = fnNow
        			if (mPeriodTempValid == true) {
        				mTempJson.put(new JSONArray("[" + mPeriodStart + "," + mPeriodTempStart + "," + mPeriodTempMax + "," + mPeriodTempMin + "," + mPeriodTempLast + "]"))
        			} else {
        				mTempJson.put(new JSONArray("[" + mPeriodStart + ",null,null,null,null]"))
        			}
        			mPeriodTempValid = false
        			mPeriodStart += HISTORY_STATS_SECONDS
        		} else {
        		    if (mPeriodTempValid == true) {
        				mTempJson.put(new JSONArray("[" + mPeriodStart + "," + mPeriodTempStart + "," + mPeriodTempMax + "," + mPeriodTempMin + "," + mPeriodTempLast + "]"))
        			} else {
        				mTempJson.put(new JSONArray("[" + mPeriodStart + ",null,null,null,null]"))
        			}
        			mPeriodTempValid = false
        			mPeriodStart += HISTORY_STATS_SECONDS
        			// Dump data now
        			if (mTempJson.length() >= HISTORY_DUMP_PERIOD_COUNT) {
        				dumpJsonArray(mTempJson, mLogFileName)
        				mTempJson = new JSONArray()
        			}	
        		}
        		mLock.unlock()
        	}
    		
    		waitMillis(1000)
    		if (mTriggerMonitorStart == true) {
    			mTriggerMonitorStart = false
    			startMonitorTemp()
    		}
    		
    		mReadQueueLock.lock()
        	if (readInProgress == true) {
        		readWaitPeriod++
        		if (readWaitPeriod > 5 && mReadGattChar != null) {
        			mGatt?.readCharacteristic(mReadGattChar)
        		}
        	}
        	mReadQueueLock.unlock()  
    	}
    	Log.i(getString(R.string.LOGTAG), "BLEService onHandleIntent exit now")
    }
    
    def connect(String address) {
        mBluetoothAdapter?.getRemoteDevice(address).connectGatt(this, false, mGattCallback);
    }
    
    var BluetoothGattCallback mGattCallback = new BluetoothGattCallback() {
        override onConnectionStateChange(BluetoothGatt gatt, int status, int newState) {
            if (newState == BluetoothProfile.STATE_CONNECTED) {
            	mDevice = gatt.getDevice()
            	mConnStatus = "transit"
            	mLock.lock()
                mScanDevMap.remove(mDevice.getAddress())
                if (mScanDevAddrList.contains(mDevice.getAddress())) {
                	var idx = mScanDevAddrList.indexOf(mDevice.getAddress())
                	mScanDevAddrList.remove(idx)
                	mScanDevNameList.remove(idx)
                }
                mLock.unlock()
                // Force DeviceListActivity update
                sendBroadcast(new Intent(getString(R.string.ACTION_REQ_DEV_LIST_AVAILABLE)))
				sendBroadcast(new Intent(getString(R.string.ACTION_REQ_DEV_LIST_CONNECTED)))
                gatt.discoverServices()
            } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                Log.w(getString(R.string.LOGTAG), "Device " + gatt.getDevice().getAddress() + " disconnected!")
                gatt.disconnect()
                gatt.close()
                if (forceConnectAddress != null) {
                	connect(forceConnectAddress)
                } else if (mDevice != null) {
                	connect(mDevice.getAddress())
                }
                mConnStatus = "transit"
                sendBroadcast(new Intent(getString(R.string.ACTION_REQ_DEV_LIST_AVAILABLE)))
				sendBroadcast(new Intent(getString(R.string.ACTION_REQ_DEV_LIST_CONNECTED)))
                
                mReadQueueLock.lock()
               	readInProgress = false
    			readWaitPeriod = 0
   				readQueue = new ArrayList<BluetoothGattCharacteristic>()
   				mReadQueueLock.unlock()
   				
   				if (r.isPlaying() == true) {
    				r.stop()
    				Log.i(getString(R.string.LOGTAG), "Stop alarm")
    			}
            }
            oadService?.onConnectionStatusChanged(newState)
        }

        override onServicesDiscovered(BluetoothGatt gatt, int status) {
            if (status == BluetoothGatt.GATT_SUCCESS) {
            	mConnStatus = "solid"
                mGatt = gatt
                mTriggerMonitorStart = true
                /*
                for (BluetoothGattService service: gatt.getServices()) {
                	Log.i(getString(R.string.LOGTAG), service.getUuid().toString())
                }
                */
                sendBroadcast(new Intent(getString(R.string.ACTION_REQ_DEV_LIST_AVAILABLE)))
				sendBroadcast(new Intent(getString(R.string.ACTION_REQ_DEV_LIST_CONNECTED)))
            } else {
                Log.w(getString(R.string.LOGTAG), "onServicesDiscovered failed")
                gatt.disconnect()
                gatt.close()
                if (mDevice != null) {
                	connect(mDevice.getAddress())
                	mConnStatus = "transit"
                }
            }
        }
        
        override onCharacteristicWrite(BluetoothGatt gatt,
                                      	BluetoothGattCharacteristic characteristic,
                                        int status) {                  	
        }

        override onCharacteristicRead(BluetoothGatt gatt,
                						BluetoothGattCharacteristic characteristic,
                						int status) {
            mReadQueueLock.lock()
            readWaitPeriod = 0
        	if (readQueue.size() > 0) {
        		mReadGattChar = readQueue.get(0)
        		readQueue.remove(0)
        		mGatt?.readCharacteristic(mReadGattChar)
				readInProgress = true
        	} else {
        		mReadGattChar = null
        		readWaitPeriod = 0
        		readInProgress = false
        	}
        	mReadQueueLock.unlock()
            oadService?.readCallback(status, characteristic)    							
        	ddActivity?.readCallback(status, characteristic)
        }
        
        override onCharacteristicChanged(BluetoothGatt gatt,
        								BluetoothGattCharacteristic characteristic) {
        	if (characteristic.getUuid().toString().equals(GATTConstants.BLE_INTERMEDIATE_TEMPERATURE)) {
        		var p = new IPC
				p.data = characteristic.getValue()
				sendBroadcast(new Intent(getString(R.string.ACTION_UPDATE_TEMP)).putExtra(getString(R.string.ACTION_EXTRA), p))	
        		handleTempUpdate(characteristic.getValue())
        	} else {
        		oadService?.onCharacteristicChanged(characteristic) 
        	}
        }
    }
    
    def checkWarnings(double temp) {
    	var float low = PreferenceManager?.getDefaultSharedPreferences(this)?.getFloat("low_temp_notify_value", 0.5f)
    	low = Utils.round((10.0f + 26.0f * low), 1) as float
    	var float high = PreferenceManager?.getDefaultSharedPreferences(this)?.getFloat("high_temp_notify_value", 0.5f)
    	high = Utils.round((36.0f + 10.0f * high), 1) as float
    	
    	if ((PreferenceManager?.getDefaultSharedPreferences(this)?.getBoolean("low_temp_notify", false) == true && temp < low) ||
    		(PreferenceManager?.getDefaultSharedPreferences(this)?.getBoolean("high_temp_notify", false) == true && temp > high)) {
    		if (r.isPlaying() == false) {    			
				r.play()
				Log.i(getString(R.string.LOGTAG), "Trigger alarm")    		    			
    		}
    	} else {
    		if (r.isPlaying() == true) {
    			r.stop()
    			Log.i(getString(R.string.LOGTAG), "Stop alarm")
    		}
    	}
    	
    	var p = new IPC
    	if (temp < low) {
    		p.colorSetting = "iDoPurple"
    	} else if (temp > high) {
    		p.colorSetting = "iDoRed"
    	} else {
    		p.colorSetting = "iDoGreen"
    	}
		sendBroadcast(new Intent(getString(R.string.ACTION_SET_COLOR)).putExtra(getString(R.string.ACTION_EXTRA), p))
    }
    
    def handleTempUpdate(byte[] data) {
		val temp = Utils.getTempC(data)
    	
    	
    	checkWarnings(temp)
    	
    	mLock.lock()        
        if (mPeriodTempValid == false) {
        	mPeriodTempStart = temp
        	mPeriodTempMax = temp
        	mPeriodTempMin = temp
        }
        mPeriodTempValid = true
        mPeriodTempLast = temp
        if (temp > mPeriodTempMax) {
        	mPeriodTempMax = temp
        }
        if (temp < mPeriodTempMin) {
        	mPeriodTempMin = temp
        }
        mLock.unlock()
    }

    def startMonitorTemp() {
    	writeCharacteristic(GATTConstants.BLE_CURRENT_TIME_SERVICE, GATTConstants.BLE_DATE_TIME, Utils.getCalendarTime())
    	waitMillis(1000)
    	setCharacteristicNotification(GATTConstants.BLE_HEALTH_THERMOMETER, GATTConstants.BLE_INTERMEDIATE_TEMPERATURE, true)
    	Log.i(getString(R.string.LOGTAG), "startMonitorTemp")
    }
    
    def static setCharacteristicNotification(String serviceUuid, String charUuid,
                                              boolean enabled) {
        var BluetoothGattService gattService = null
        var BluetoothGattCharacteristic gattChar = null
        var BluetoothGattDescriptor descriptor = null
        
        gattService = mGatt?.getService(UUID.fromString(serviceUuid));
        gattChar = gattService?.getCharacteristic(UUID.fromString(charUuid));               
        descriptor = gattChar?.getDescriptor(UUID.fromString(GATTConstants.BLE_GATT_CCCD));
        if (enabled == true) {
        	descriptor?.setValue(BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE);
        } else {
        	descriptor?.setValue(BluetoothGattDescriptor.DISABLE_NOTIFICATION_VALUE);
        }
        if (descriptor != null) {
        	mGatt?.writeDescriptor(descriptor)
        	if (gattChar != null) {
        		mGatt?.setCharacteristicNotification(gattChar, enabled)
        	}
        }
    }
    
    def static writeCharacteristic(String serviceUuid, String charUuid, byte[] data) {
        var BluetoothGattService gattService = null
        var BluetoothGattCharacteristic gattChar = null
        
        gattService = mGatt?.getService(UUID.fromString(serviceUuid))
        gattChar = gattService?.getCharacteristic(UUID.fromString(charUuid))
        gattChar?.setValue(data)
        if (gattChar != null) {
        	mGatt?.writeCharacteristic(gattChar)
        }
    }
    
    def static writeCharacteristicWithoutRsp(String serviceUuid, String charUuid, byte[] data) {
        var BluetoothGattService gattService = null
        var BluetoothGattCharacteristic gattChar = null
        
        gattService = mGatt?.getService(UUID.fromString(serviceUuid))
        gattChar = gattService?.getCharacteristic(UUID.fromString(charUuid))
        gattChar?.setValue(data)
        gattChar?.setWriteType(BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE)
        if (gattChar != null) {
        	mGatt?.writeCharacteristic(gattChar)
        }
    }
    
    def static readCharacteristic(String serviceUuid, String charUuid) {
        var BluetoothGattService gattService = null
        var BluetoothGattCharacteristic gattChar = null
        
        gattService = mGatt?.getService(UUID.fromString(serviceUuid))
        gattChar = gattService?.getCharacteristic(UUID.fromString(charUuid))
        if (gattChar != null) {
        	Log.i("iDoSmart", "read char " + charUuid)        	
        	mReadQueueLock.lock()
        	if (readInProgress == false) {
        		readInProgress = true
        		mReadGattChar = gattChar
        		readWaitPeriod = 0
        		mGatt?.readCharacteristic(gattChar)
        	} else {
        		readQueue.add(gattChar)
        	}
        	mReadQueueLock.unlock()     	
        }
    }
    
    def dumpJsonArray(JSONArray jArray, String fileName) {
		var FileOutputStream reportOutput = null
    	var fn = new File(folderName + fileName)
		if (!fn.exists()) {
			try {
				fn.createNewFile()
			} catch (IOException e2) {
				// TODO Auto-generated catch block
				e2.printStackTrace()
			}			
		}
		
		var periodStart = jArray.getJSONArray(0).getInt(0)
		Log.i(getString(R.string.LOGTAG), "dump start ts: " + jArray.getJSONArray(0).getInt(0) + " size: " + jArray.length())
		
		// Read JSON from file, do the merge
		var existingString = CharStreams.toString(new InputStreamReader(new FileInputStream(fn), Charsets.UTF_8))
		var JSONArray existingJsonArray
		if (existingString.length() > 0) {
			existingJsonArray = new JSONArray(existingString)
			// Check if there is gap between latest record and current one,
			// fill with null
			var lastStart = existingJsonArray.getJSONArray(existingJsonArray.length() - 1).getInt(0)
			if ((lastStart + HISTORY_STATS_SECONDS) < periodStart) {
				lastStart += HISTORY_STATS_SECONDS
				while (lastStart < periodStart) {
					existingJsonArray.put(new JSONArray("[" + lastStart + ",null,null,null,null]"))
					lastStart += HISTORY_STATS_SECONDS
				}

			} else if ((lastStart + HISTORY_STATS_SECONDS) > periodStart) {
				Log.w(getString(R.string.LOGTAG), "Warning: duplicated entries in json log")
				var JSONArray backup = new JSONArray()
				for (var i = 0; i < existingJsonArray.length(); i++) {
					if (existingJsonArray.getJSONArray(i).getInt(0) < periodStart) {
						backup.put(existingJsonArray.getJSONArray(i))
					}
				}
				existingJsonArray = backup
			}
		} else {
			existingJsonArray = new JSONArray()
		}
		
		for (var i = 0; i < jArray.length(); i++) {
			existingJsonArray.put(jArray.getJSONArray(i))
		}
		
		// Write merged JSON to file
		try {
			reportOutput = new FileOutputStream(fn)
			if (reportOutput != null) {
				var osw = new OutputStreamWriter(reportOutput)
				osw.write(existingJsonArray.toString())
				osw.flush()
				osw.close()
			}
			reportOutput.close()
		} catch (FileNotFoundException e1) {
			// Fall through
			e1.printStackTrace()
		} catch (IOException e) {
			// TODO Auto-generated catch block
			e.printStackTrace()
		}	
    }
}