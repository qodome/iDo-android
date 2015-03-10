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

class BLEService extends IntentService {
	var BluetoothManager mBluetoothManager
    var BluetoothAdapter mBluetoothAdapter
    static public var BluetoothDevice mDevice = null
    static public var BluetoothGatt mGatt = null
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
        		sendBroadcast(new Intent(getString(R.string.ACTION_REQ_DEV_LIST_AVAILABLE)))
        		mScanDevNameList.add(device.getName())
        		mScanDevAddrList.add(device.getAddress())
        	}        	
        	mLock.unlock()
        }
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
				if (mDevice != null) {
					var p = new IPC
					p.devAddr = new ArrayList<String>()
					p.devAddr.add(mDevice.getAddress())
					p.devName = new ArrayList<String>()
					p.devName.add(mDevice.getName())
					sendBroadcast(new Intent(getString(R.string.ACTION_RSP_DEV_LIST_CONNECTED)).putExtra(getString(R.string.ACTION_EXTRA), p))
				}
			} else if (intent.getAction().equals(getString(R.string.ACTION_CONNECT_TO_DEVICE))) {
				// Disconnect with previous connection if there is any
				mGatt?.disconnect()
                mGatt?.close()
                mGatt = null
                mDevice = null
				
				var IPC p = intent.getParcelableExtra(getString(R.string.ACTION_EXTRA))
				forceConnectAddress = p.devAddr.get(0)
				connect(forceConnectAddress)
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
		intentFilter.addAction(getString(R.string.ACTION_STOP_SCAN))
		return intentFilter
	}
	
	new() {
		super("BLEService")
	}
	
	override onCreate() {
    	super.onCreate()
    	
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
        
        var note = new Notification( 0, null, System.currentTimeMillis())
    	note.flags = Notification.FLAG_NO_CLEAR
    	startForeground(42, note)
    	
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
    
	override onHandleIntent(Intent intent) {                
    	Log.i(getString(R.string.LOGTAG), "onHandleIntent got intent")    	
    	mPeriodStart = Calendar.getInstance().getTimeInMillis() / 1000L
    	mPeriodStart = (mPeriodStart / 300) * 300

    	while (true) {
    		val timeNow = Calendar.getInstance().getTimeInMillis() / 1000L 
        	if ((timeNow - mPeriodStart) >= 300) {
        		mLock.lock()
        		if (mPeriodTempValid == true) {
        			mTempJson.put(new JSONArray("[" + mPeriodStart + "," + mPeriodTempStart + "," + mPeriodTempMax + "," + mPeriodTempMin + "," + mPeriodTempLast + "]"))
        		} else {
        			mTempJson.put(new JSONArray("[" + mPeriodStart + ",null,null,null,null]"))
        		}
        		mPeriodTempValid = false
        		mPeriodStart += 300
        		// Dump data now
        		if (mTempJson.length() >= 2) {
        			dumpJsonArray(mTempJson, mPeriodStart)
        			mTempJson = new JSONArray()
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
        		if (readWaitPeriod > 5) {
        			mGatt?.readCharacteristic(mReadGattChar)
        		}
        	}
        	mReadQueueLock.unlock()  
    	}
    }
    
    def connect(String address) {
        mBluetoothAdapter?.getRemoteDevice(address).connectGatt(this, false, mGattCallback);
    }
    
    var BluetoothGattCallback mGattCallback = new BluetoothGattCallback() {
        override onConnectionStateChange(BluetoothGatt gatt, int status, int newState) {
            if (newState == BluetoothProfile.STATE_CONNECTED) {
            	mDevice = gatt.getDevice()
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
                mGatt = gatt
                mTriggerMonitorStart = true
                /*
                for (BluetoothGattService service: gatt.getServices()) {
                	Log.i(getString(R.string.LOGTAG), service.getUuid().toString())
                }
                */
            } else {
                Log.w(getString(R.string.LOGTAG), "onServicesDiscovered failed")
                gatt.disconnect()
                gatt.close()
                if (mDevice != null) {
                	connect(mDevice.getAddress())
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
    
    def dumpJsonArray(JSONArray jArray, long periodStart) {
		var FileOutputStream reportOutput = null

		var c = Calendar.getInstance()
        var fileName = new String(c.get(Calendar.YEAR) + "_" + (c.get(Calendar.MONTH) + 1) + "_" + c.get(Calendar.DAY_OF_MONTH) + ".json")
    	var fn = new File(folderName + fileName)
		if (!fn.exists()) {
			try {
				fn.createNewFile()
			} catch (IOException e2) {
				// TODO Auto-generated catch block
				e2.printStackTrace()
			}			
		}
		
		// Read JSON from file, do the merge
		var existingString = CharStreams.toString(new InputStreamReader(new FileInputStream(fn), Charsets.UTF_8))
		var JSONArray existingJsonArray
		if (existingString.length() > 0) {
			existingJsonArray = new JSONArray(existingString)
			// Check if there is gap between latest record and current one,
			// fill with null
			var lastStart = existingJsonArray.getJSONArray(existingJsonArray.length() - 1).getInt(0)
			if ((lastStart + 300) < periodStart) {
				lastStart += 300
				while (lastStart < periodStart) {
					existingJsonArray.put(new JSONArray("[" + lastStart + ",null,null,null,null]"))
					lastStart += 300
				}
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