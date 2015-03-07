package com.qodome.idosmart

import android.app.IntentService
import android.util.Log
import android.content.Intent
import android.bluetooth.BluetoothGattCharacteristic
import java.io.InputStream
import com.google.common.io.ByteStreams
import java.util.Arrays
import android.bluetooth.BluetoothProfile
import java.util.concurrent.locks.Lock
import java.util.concurrent.locks.ReentrantLock

class OADService extends IntentService {
	enum OADStatus {
		WAIT_ON_FV,
		ALREADY_LATEST,
		NOT_SUPPORTED,
		DO_UPDATE_WITH_A,
		DO_UPDATE_WITH_B,
		WAITING,
		OADING,
		DISCONNECTED_AFTER_OAD,
		CHECK_OAD_RESULT,
		SUCCESS,
		FAIL
	}

	var OADStatus status
	var int sleepCnt
	var int notifyIdCnt
	var int writeIdx
	var int blockCntDown
	var int sleepPeriod
	val blockCount = 7808 // 0x1E80
	var Lock l
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
    	notifyIdCnt = 0
    	writeIdx = 0
    	blockCntDown = 0
    	l = new ReentrantLock()
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
    	sleepCnt = 0
    	while (status == OADStatus.WAIT_ON_FV) {
    		sleepCnt++
    		if (sleepCnt > 10) {
    			sendStatusUpdate("Timeout")
    			return
    		}
    		waitMillis(1000)
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
    	
    	var InputStream is = null
    	if (status == OADStatus.DO_UPDATE_WITH_A) {
    		is = getResources().openRawResource(R.raw.img_a_03_101)
    	} else {
    		is = getResources().openRawResource(R.raw.img_b_03_101)
    	}

		// Prepare raw meat
    	Utils.bytes = ByteStreams.toByteArray(is)
    	    	
    	// Enable OAD notifications
    	BLEService.setCharacteristicNotification(GATTConstants.BLE_IDO1_OAD_SERVICE, GATTConstants.BLE_IDO1_OAD_IDENTIFY, true)
    	waitMillis(1000)
    	BLEService.setCharacteristicNotification(GATTConstants.BLE_IDO1_OAD_SERVICE, GATTConstants.BLE_IDO1_OAD_BLOCK, true)
    	waitMillis(1000)
    	
    	// Trigger OAD start
    	BLEService.writeCharacteristic(GATTConstants.BLE_IDO1_OAD_SERVICE, GATTConstants.BLE_IDO1_OAD_IDENTIFY, Arrays.copyOfRange(Utils.bytes, 4, 12))    	
    	status = OADStatus.WAITING
    	sleepCnt = 0
    	while (status == OADStatus.WAITING) {
    		sleepCnt++
    		if (sleepCnt > 20) {
    			sendStatusUpdate("Timeout")
    			return
    		}
    		waitMillis(1000)
    	}
    	
    	if (status == OADStatus.NOT_SUPPORTED) {
    		sendStatusUpdate("Not Supported")
    		return    		
    	}
    	
    	var boolean loopCheck = true
    	while (loopCheck) {
    		l.lock()
    		val next = writeIdx
            if (next < blockCount) {
                writeIdx++
            }
            l.unlock()
            if (blockCntDown > 0) {
                blockCntDown--
                sleepPeriod = 500
            } else {
                sleepPeriod = 10
            }
            if (next < blockCount) {
                sleepCnt = 0
                BLEService.writeCharacteristicWithoutRsp(GATTConstants.BLE_IDO1_OAD_SERVICE, GATTConstants.BLE_IDO1_OAD_BLOCK, Utils.parepareBlock(next, Arrays.copyOfRange(Utils.bytes, (16 * next), (16 * next + 16))))
                if (next % 78 == 0) {
                    val percent = next / 78
                    sendStatusUpdate(percent + "%")
                }
                waitMillis(sleepPeriod)
            } else {
                if (status == OADStatus.DISCONNECTED_AFTER_OAD || status == OADStatus.CHECK_OAD_RESULT) {
                    loopCheck = false
                }
                // Disconnect check
                waitMillis(1000)
                sleepCnt++
                if (sleepCnt > 60) {
                    sendStatusUpdate("Timeout")
    				return
                }
            }
    	}
    	
    	sleepCnt = 0
        while (status == OADStatus.DISCONNECTED_AFTER_OAD) {
            waitMillis(1000)
            sleepCnt++
            if (sleepCnt > 20) {
                sendStatusUpdate("Timeout")
    			return
            }
        }
        if (status != OADStatus.CHECK_OAD_RESULT) {
            sendStatusUpdate("Timeout")
    		return
        }
        // Wait 2 seconds to allow service discovery
        waitMillis(2000)
        BLEService.readCharacteristic(GATTConstants.BLE_DEVICE_INFORMATION, GATTConstants.BLE_FIRMWARE_REVISION_STRING)
    	
    	sleepCnt = 0
        while (status == OADStatus.CHECK_OAD_RESULT) {
            waitMillis(1000)
            sleepCnt++
            if (sleepCnt > 20) {
                sendStatusUpdate("Timeout")
    			return
            }
        }
        if (status == OADStatus.SUCCESS) {
        	sendStatusUpdate("SUCCESS")
        } else {
        	sendStatusUpdate("FAIL")
        }
    }
	
	public def onConnectionStatusChanged(int newState) {
		if (newState == BluetoothProfile.STATE_CONNECTED) {
			if (status == OADStatus.DISCONNECTED_AFTER_OAD) {
				status = OADStatus.CHECK_OAD_RESULT
			}
		} else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
			l.lock()
			if (writeIdx >= blockCount && status == OADStatus.OADING) {
                Log.i(getString(R.string.LOGTAG), "Device disconnected after OAD")
                status = OADStatus.DISCONNECTED_AFTER_OAD
            }
            l.unlock()
		}
	}
	
	public def onCharacteristicChanged(BluetoothGattCharacteristic characteristic) {
		if (characteristic.getUuid().toString().equals(GATTConstants.BLE_IDO1_OAD_IDENTIFY)) {
			notifyIdCnt++
			if (notifyIdCnt > 5) {
				status = OADStatus.NOT_SUPPORTED
				return
			}
			BLEService.writeCharacteristic(GATTConstants.BLE_IDO1_OAD_SERVICE, GATTConstants.BLE_IDO1_OAD_IDENTIFY, Arrays.copyOfRange(Utils.bytes, 4, 12))
		} else if (characteristic.getUuid().toString().equals(GATTConstants.BLE_IDO1_OAD_BLOCK)) {
			var sb = new StringBuilder(characteristic.getValue().length * 3)
        	for (byte b: characteristic.getValue()) {
        		sb.append(String.format("%02x ", b));
        	}
        	Log.i(getString(R.string.LOGTAG), "OADBlock got Notification: " + sb.toString());
			
			status = OADStatus.OADING
			l.lock()
			Log.i(getString(R.string.LOGTAG), "writeIdx " + writeIdx + " to " + Utils.getWriteIdx(characteristic.getValue()))
			writeIdx = Utils.getWriteIdx(characteristic.getValue())
			l.unlock()
			blockCntDown = 10
			Log.i(getString(R.string.LOGTAG), "get block notification update")          
		}
	}
	
	public def readCallback(int retStatus, BluetoothGattCharacteristic characteristic) {
    	if (characteristic.getUuid().toString().equals(GATTConstants.BLE_FIRMWARE_REVISION_STRING)) {
    		if (retStatus == 0) {
    			if (status != OADStatus.CHECK_OAD_RESULT) {
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
    				Log.i(getString(R.string.LOGTAG), new String(characteristic.getValue()))
    				if (getString(R.string.IMG_1_0_1_03_A).equals(new String(characteristic.getValue())) ||
    					getString(R.string.IMG_1_0_1_03_B).equals(new String(characteristic.getValue()))) {
    					Log.i(getString(R.string.LOGTAG), "success")
    					status = OADStatus.SUCCESS
    				} else {
    					Log.i(getString(R.string.LOGTAG), "fail")
    					status = OADStatus.FAIL
    				}
    			}
    		} else {
    			// Not Supported
    			status = OADStatus.NOT_SUPPORTED
    		}
    	}	
    }
}