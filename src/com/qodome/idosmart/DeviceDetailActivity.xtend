package com.qodome.idosmart

import org.xtendroid.app.AndroidActivity
import android.os.Bundle
import org.xtendroid.app.OnCreate
import org.eclipse.xtend.lib.annotations.Accessors
import java.util.List
import java.util.ArrayList
import org.xtendroid.adapter.BeanAdapter
import android.bluetooth.BluetoothGattCharacteristic
import android.widget.AdapterView.OnItemClickListener
import android.view.View
import android.widget.AdapterView
import android.content.Intent
import android.util.Log
import android.app.AlertDialog
import android.widget.EditText
import android.content.DialogInterface

@Accessors class DevDetailElement {
	String deviceDetailKey
	String deviceDetailValue
}

@AndroidActivity(R.layout.activity_device_detail) class DeviceDetailActivity {
	var ddActivity = this
	var List<DevDetailElement> devDetailHead
	var List<DevDetailElement> devDetailContent
	
	
	@OnCreate
    def init(Bundle savedInstanceState) {
    	BLEService.ddActivity = this
    	
    	devDetailHead = new ArrayList<DevDetailElement>()
    	devDetailContent = new ArrayList<DevDetailElement>()
    	var devElem = new DevDetailElement()
    	devElem.deviceDetailKey = "Name"
    	devElem.deviceDetailValue = BLEService.mDevice?.getName()
    	devDetailHead.add(devElem)
    	devElem = new DevDetailElement()
    	devElem.deviceDetailKey = "Update"
    	devElem.deviceDetailValue = "N/A"
    	devDetailHead.add(devElem)
    	deviceDetailHead.adapter = new BeanAdapter<DevDetailElement>(this, R.layout.element_device_detail, devDetailHead)
    	BLEService.readCharacteristic(GATTConstants.BLE_DEVICE_INFORMATION, GATTConstants.BLE_MODEL_NUMBER_STRING)
    }

	override onDestroy() {
    	BLEService.ddActivity = null
    	super.onDestroy()
    }
    
    public def readCallback(int status, BluetoothGattCharacteristic characteristic) {
    	if (characteristic.getUuid().toString().equals(GATTConstants.BLE_MODEL_NUMBER_STRING)) {
    		if (status == 0) {
    			if (getString(R.string.IDO_MODEL_NAME).equals(new String(characteristic.getValue()))) {
    				runOnUiThread[
    				devDetailHead.remove(1)
    				var devElem = new DevDetailElement()
    				devElem.deviceDetailKey = "Update"
    				devElem.deviceDetailValue = "Available"
    				devDetailHead.add(devElem)
    				deviceDetailHead.adapter = new BeanAdapter<DevDetailElement>(this, R.layout.element_device_detail, devDetailHead)
    				deviceDetailHead.setOnItemClickListener(new OnItemClickListener() {
          				override onItemClick(AdapterView<?> parent, View view, int position, long id) {
							if (position == 1) {
								startActivity(new Intent(ddActivity, typeof(OADActivity)))
							}
              			}
            		})
            		]
            		// Check firmware version
            		BLEService.readCharacteristic(GATTConstants.BLE_DEVICE_INFORMATION, GATTConstants.BLE_FIRMWARE_REVISION_STRING)
    			}
    		}
    	} else if (characteristic.getUuid().toString().equals(GATTConstants.BLE_FIRMWARE_REVISION_STRING)) {
    		if (status == 0) {
    			var str = new String(characteristic.getValue())
    			if (!str.substring(0, 5).equals("1.0.0")) {
    				deviceDetailHead.setOnItemClickListener(new OnItemClickListener() {
          				override onItemClick(AdapterView<?> parent, View view, int position, long id) {
							if (position == 1) {
								startActivity(new Intent(ddActivity, typeof(OADActivity)))
							} else if (position == 0) {
								var alert = new AlertDialog.Builder(ddActivity).setTitle("New Name").setMessage("Please enter iDo's new name")
								val input = new EditText(ddActivity)
								alert.setView(input)
								alert.setPositiveButton("OK", new DialogInterface.OnClickListener() {
									override onClick(DialogInterface dialog, int whichButton) {
										Log.i(getString(R.string.LOGTAG), "test " + input.getText().toString())
										BLEService.writeCharacteristic(GATTConstants.BLE_QODOME_SERVICE, GATTConstants.BLE_QODOME_SET_NAME, input.getText().toString().getBytes("UTF-8"))
  									}
								});
								alert.setNegativeButton("Cancel", new DialogInterface.OnClickListener() {
  									override onClick(DialogInterface dialog, int whichButton) {
  									}
								});
								alert.show()
							}
              			}
            		})
    			}	
    		}
    		BLEService.readCharacteristic(GATTConstants.BLE_DEVICE_INFORMATION, GATTConstants.BLE_SERIAL_NUMBER_STRING)
    	}  else if (characteristic.getUuid().toString().equals(GATTConstants.BLE_SERIAL_NUMBER_STRING)) {
    		if (status == 0) {
    			runOnUiThread[
    			var devElem = new DevDetailElement()
    			devElem.deviceDetailKey = "Serial Number"
    			devElem.deviceDetailValue = new String(characteristic.getValue())
    			devDetailContent.add(devElem)
    			deviceDetailContents.adapter = new BeanAdapter<DevDetailElement>(this, R.layout.element_device_detail, devDetailContent)
    			]
    		}
    		BLEService.readCharacteristic(GATTConstants.BLE_DEVICE_INFORMATION, GATTConstants.BLE_SOFTWARE_REVISION_STRING)
    	}  else if (characteristic.getUuid().toString().equals(GATTConstants.BLE_SOFTWARE_REVISION_STRING)) {
    		if (status == 0) {
    			runOnUiThread[
    			var devElem = new DevDetailElement()
    			devElem.deviceDetailKey = "Software Revision"
    			devElem.deviceDetailValue = new String(characteristic.getValue())
    			devDetailContent.add(devElem)
    			deviceDetailContents.adapter = new BeanAdapter<DevDetailElement>(this, R.layout.element_device_detail, devDetailContent)
    			]
    		}
    		BLEService.readCharacteristic(GATTConstants.BLE_DEVICE_INFORMATION, GATTConstants.BLE_MANUFACTURER_NAME_STRING)
    	}  else if (characteristic.getUuid().toString().equals(GATTConstants.BLE_MANUFACTURER_NAME_STRING)) {
    		if (status == 0) {
    			runOnUiThread[
    			var devElem = new DevDetailElement()
    			devElem.deviceDetailKey = "Manufacture"
    			devElem.deviceDetailValue = new String(characteristic.getValue())
    			devDetailContent.add(devElem)
    			deviceDetailContents.adapter = new BeanAdapter<DevDetailElement>(this, R.layout.element_device_detail, devDetailContent)
    			]
    		}
    	}
    }
}