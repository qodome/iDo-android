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

class BLEService extends IntentService {
	var BluetoothManager mBluetoothManager
    var BluetoothAdapter mBluetoothAdapter
    var String mDevAddr
    var BluetoothDevice mDevice
    var Map<String, BluetoothDevice> mScanDevMap
    var BluetoothGatt mGatt
    var String folderName
    var List<ScanFilter> crmFilterList
    var ScanSettings crmScanSetting
    
    var ScanCallback mLeScanCallback =
            new ScanCallback() {
        override onScanResult(int callbackType, ScanResult result) {
        	if (!mScanDevMap.containsKey(result.getDevice().getAddress())) {
        		Log.i(getString(R.string.LOGTAG), "Scan found device: " + result.getDevice().getAddress())
        		mScanDevMap.put(result.getDevice().getAddress(), result.getDevice())
        	}        	
        }
    }
	
	var BroadcastReceiver mServiceActionReceiver = new BroadcastReceiver() {
		override onReceive(Context context, Intent intent) {
			if (intent.getAction().equals(getString(R.string.ACTION_REQ_DEV_LIST))) {
				var p = new IPC
				p.devAddr = new ArrayList<String>(mScanDevMap.keySet())
				p.devName = p.devAddr.map[ devAddr |
					return mScanDevMap.get(devAddr).getName()
				]
				var intent2 = new Intent(getString(R.string.ACTION_RSP_DEV_LIST))
				intent2.putExtra(getString(R.string.ACTION_EXTRA), p)
				sendBroadcast(intent2)
			}
		}
	}
	
	def serviceActionIntentFilter() {
		var intentFilter = new IntentFilter();
		intentFilter.addAction(getString(R.string.ACTION_REQ_DEV_LIST));
		return intentFilter;
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
        mDevAddr = new String("")
        mScanDevMap = new HashMap<String, BluetoothDevice>()
        crmFilterList = new ArrayList<ScanFilter>()
        crmFilterList.add(new ScanFilter.Builder().setServiceUuid(ParcelUuid.fromString("00001809-0000-1000-8000-00805f9b34fb")).build())
        crmScanSetting = new ScanSettings.Builder().setScanMode(ScanSettings.SCAN_MODE_BALANCED).build()
        Log.i(getString(R.string.LOGTAG), "BLEService created")
        
        mBluetoothAdapter?.getBluetoothLeScanner().startScan(crmFilterList, crmScanSetting, mLeScanCallback)
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
    		waitMillis(500)
    	}
    }
}