package com.qodome.idosmart

import android.app.IntentService
import android.util.Log
import android.content.Intent
import android.bluetooth.BluetoothGattCharacteristic

class OADService extends IntentService {
	enum OADStatus {
		WAIT_ON_FV,
		ALREADY_LATEST,
		NOT_SUPPORTED,
		DO_UPDATE_WITH_A,
		DO_UPDATE_WITH_B
	}

	var OADStatus status
	public static var String currentVersion = null
	public static var String targetVersion = null
	public static var String oadStatus = null
	
	new() {
		super("OADService")
	}
	
	override onCreate() {
    	super.onCreate()
    	BLEService.oadService = this
    	status = OADStatus.WAIT_ON_FV
    	currentVersion = null
    	targetVersion = null
    	oadStatus = null
        Log.i(getString(R.string.LOGTAG), "OADService created")
    }
    
    override onDestroy() {
    	BLEService.oadService = null
    	super.onDestroy()
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
    
    def sendStatusUpdate(String msg) {
    	var p = new IPC
		p.oadStatus = msg
		sendBroadcast(new Intent(getString(R.string.ACTION_OAD_STATUS)).putExtra(getString(R.string.ACTION_EXTRA), p))
    	oadStatus = msg
    }
    
    def sendOADVersion(String current, String target) {
    	var p = new IPC
		p.oadCurrent = current
		p.oadTarget = target
		sendBroadcast(new Intent(getString(R.string.ACTION_OAD_VERSION)).putExtra(getString(R.string.ACTION_EXTRA), p))
    	currentVersion = current
    	targetVersion = target
    }
    
	override onHandleIntent(Intent intent) {                
    	Log.i(getString(R.string.LOGTAG), "OADService onHandleIntent got started")
    	
    	BLEService.readCharacteristic(GATTConstants.BLE_DEVICE_INFORMATION, GATTConstants.BLE_FIRMWARE_REVISION_STRING)
    	while (status == OADStatus.WAIT_ON_FV) {
    		waitMillis(100)
    	}
    	
    	Log.i(getString(R.string.LOGTAG), "OADService onHandleIntent check status")
    	if (status == OADStatus.ALREADY_LATEST) {
    		sendStatusUpdate("Image Already Latest")
    		return
    	} else if (status == OADStatus.NOT_SUPPORTED) {
    		sendStatusUpdate("Not Supported")
    		return
    	}
    	
    	if (status == OADStatus.DO_UPDATE_WITH_A) {
    		sendOADVersion(currentVersion, getString(R.string.IMG_1_0_1_03_A))
    	} else if (status == OADStatus.DO_UPDATE_WITH_B) {
    		sendOADVersion(currentVersion, getString(R.string.IMG_1_0_1_03_B))
    	} else {
    		Log.e(getString(R.string.LOGTAG), "OADService BUG!")
    		return
    	}
    	
    	while (true) {
    		waitMillis(100)
    	}
    	
    }
	
	public def readCallback(int status, BluetoothGattCharacteristic characteristic) {
		Log.i(getString(R.string.LOGTAG), "OADService readCallback status: " + status + " " + characteristic.getUuid().toString())
    	if (characteristic.getUuid().toString().equals(GATTConstants.BLE_FIRMWARE_REVISION_STRING)) {
    		if (status == 0) {
    			currentVersion = new String(characteristic.getValue())
    			if (getString(R.string.IMG_1_0_1_03_A).equals(new String(characteristic.getValue())) ||
    				getString(R.string.IMG_1_0_1_03_B).equals(new String(characteristic.getValue()))) {
    				status = OADStatus.ALREADY_LATEST
    			} else {
    				var str = new String(characteristic.getValue())
    				if (str.contains("A")) {
    					status = OADStatus.DO_UPDATE_WITH_B
    				} else {
    					status = OADStatus.DO_UPDATE_WITH_A
    				}
    				
    			}
    		} else {
    			// Not Supported
    			status = OADStatus.NOT_SUPPORTED
    		}
    	}	
    }
}