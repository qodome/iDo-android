package com.qodome.idosmart

import android.bluetooth.le.ScanCallback
import android.app.IntentService
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattService
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
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

class BLEService extends IntentService {
	var BluetoothManager mBluetoothManager
    var BluetoothAdapter mBluetoothAdapter
    static var BluetoothDevice mDevice
    static var BluetoothGatt mGatt    
    static var Map<String, BluetoothDevice> mScanDevMap
    var String folderName
    var List<ScanFilter> crmFilterList
    var ScanSettings crmScanSetting
    var boolean mScanStarted
    var boolean mTriggerMonitorStart
    
    var ScanCallback mLeScanCallback =
            new ScanCallback() {
        override onScanResult(int callbackType, ScanResult result) {
        	if (!mScanDevMap.containsKey(result.getDevice().getAddress())) {
        		Log.i(getString(R.string.LOGTAG), "Scan found device: " + result.getDevice().getAddress())
        		mScanDevMap.put(result.getDevice().getAddress(), result.getDevice())
        		sendBroadcast(new Intent(getString(R.string.ACTION_REQ_DEV_LIST_AVAILABLE)))
        	}        	
        }
    }
	
	var BroadcastReceiver mServiceActionReceiver = new BroadcastReceiver() {
		override onReceive(Context context, Intent intent) {
			if (intent.getAction().equals(getString(R.string.ACTION_REQ_DEV_LIST_AVAILABLE))) {
				if (mScanStarted == false) {
					mScanStarted = true
					mBluetoothAdapter?.getBluetoothLeScanner().startScan(crmFilterList, crmScanSetting, mLeScanCallback)
				}
				
				var p = new IPC
				p.devAddr = new ArrayList<String>(mScanDevMap.keySet())
				p.devName = p.devAddr.map[ devAddr |
					return mScanDevMap.get(devAddr).getName()
				]
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
				connect(p.devAddr.get(0))
			} else if (intent.getAction().equals(getString(R.string.ACTION_STOP_SCAN))) {
				if (mScanStarted == true) {
					mScanStarted = false
					mBluetoothAdapter?.getBluetoothLeScanner().stopScan(mLeScanCallback)					
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
        mDevice = null
        mGatt = null
        mScanStarted = false
        mTriggerMonitorStart = false
        mScanDevMap = new HashMap<String, BluetoothDevice>()
        crmFilterList = new ArrayList<ScanFilter>()
        crmFilterList.add(new ScanFilter.Builder().setServiceUuid(ParcelUuid.fromString("00001809-0000-1000-8000-00805f9b34fb")).build())
        crmScanSetting = new ScanSettings.Builder().setScanMode(ScanSettings.SCAN_MODE_BALANCED).build()
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
    	while (true) {
    		waitMillis(50)
    		if (mTriggerMonitorStart == true) {
    			mTriggerMonitorStart = false
    			startMonitorTemp()
    		}
    	}
    }
    
    def connect(String address) {
        mBluetoothAdapter?.getRemoteDevice(address).connectGatt(this, false, mGattCallback);
    }
    
    var BluetoothGattCallback mGattCallback = new BluetoothGattCallback() {
        override onConnectionStateChange(BluetoothGatt gatt, int status, int newState) {
            if (newState == BluetoothProfile.STATE_CONNECTED) {
            	mDevice = gatt.getDevice()
                mScanDevMap.remove(mDevice.getAddress())
                sendBroadcast(new Intent(getString(R.string.ACTION_REQ_DEV_LIST_AVAILABLE)))
				sendBroadcast(new Intent(getString(R.string.ACTION_REQ_DEV_LIST_CONNECTED)))
                gatt.discoverServices()
            } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                Log.w(getString(R.string.LOGTAG), "Device " + gatt.getDevice().getAddress() + " disconnected!")
                gatt.disconnect()
                gatt.close()
                if (mDevice != null) {
                	connect(mDevice.getAddress())
                }
            }
        }

        override onServicesDiscovered(BluetoothGatt gatt, int status) {
            if (status == BluetoothGatt.GATT_SUCCESS) {
                mGatt = gatt
                mTriggerMonitorStart = true
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
        	Log.i(getString(R.string.LOGTAG), "onCharacteristicWrite")                    	
        }

        override onCharacteristicRead(BluetoothGatt gatt,
                						BluetoothGattCharacteristic characteristic,
                						int status) {
                	
        }
        
        override onCharacteristicChanged(BluetoothGatt gatt,
        								BluetoothGattCharacteristic characteristic) {
        	if (characteristic.getUuid().toString().equals(GATTConstants.BLE_INTERMEDIATE_TEMPERATURE)) {
        		var p = new IPC
				p.data = characteristic.getValue()
				sendBroadcast(new Intent(getString(R.string.ACTION_UPDATE_TEMP)).putExtra(getString(R.string.ACTION_EXTRA), p))
        	}
        }
    }

    def startMonitorTemp() {
    	writeCharacteristic(GATTConstants.BLE_CURRENT_TIME_SERVICE, GATTConstants.BLE_DATE_TIME, Utils.getCalendarTime())
    	waitMillis(1000)
    	setCharacteristicNotification(GATTConstants.BLE_HEALTH_THERMOMETER, GATTConstants.BLE_INTERMEDIATE_TEMPERATURE, true)
    	Log.i(getString(R.string.LOGTAG), "startMonitorTemp")
    }
    
    def setCharacteristicNotification(String serviceUuid, String charUuid,
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
        		Log.i(getString(R.string.LOGTAG), "set notify")
        		mGatt?.setCharacteristicNotification(gattChar, enabled)
        	}
        }
    }
    
    def static writeCharacteristic(String serviceUuid, String charUuid, byte[] data) {
        var BluetoothGattService gattService = null
        var BluetoothGattCharacteristic gattChar = null
        
        gattService = mGatt?.getService(UUID.fromString(serviceUuid))
        gattChar = gattService?.getCharacteristic(UUID.fromString(charUuid))
        gattService = mGatt?.getService(UUID.fromString(serviceUuid))
        gattChar = gattService?.getCharacteristic(UUID.fromString(charUuid))
        gattChar?.setValue(data)
        if (gattChar != null) {
        	Log.i("iDoSmart", "write char")
        	mGatt?.writeCharacteristic(gattChar)
        }
    }
    
    def static readCharacteristic(String serviceUuid, String charUuid) {
        var BluetoothGattService gattService = null
        var BluetoothGattCharacteristic gattChar = null
        
        gattService = mGatt?.getService(UUID.fromString(serviceUuid))
        gattChar = gattService?.getCharacteristic(UUID.fromString(charUuid)) 
        gattService = mGatt?.getService(UUID.fromString(serviceUuid))
        gattChar = gattService?.getCharacteristic(UUID.fromString(charUuid))
        if (gattChar != null) {
        	mGatt?.readCharacteristic(gattChar)        	
        }
    }
}