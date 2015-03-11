package com.qodome.idosmart

import android.view.View
import org.xtendroid.app.AndroidActivity
import android.os.Bundle
import org.xtendroid.app.OnCreate
import android.content.Intent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.IntentFilter
import android.util.Log
import android.content.SharedPreferences
import android.preference.PreferenceManager
import android.bluetooth.BluetoothManager
import android.app.AlertDialog
import android.content.DialogInterface
import android.bluetooth.BluetoothAdapter

@AndroidActivity(R.layout.activity_main) class MainActivity {
	var selfActivity = this
	var boolean doNotSupport = false

	@OnCreate
    def init(Bundle savedInstanceState) {
    	var bluetoothManager = getSystemService("bluetooth") as BluetoothManager
        var bluetoothAdapter = bluetoothManager?.getAdapter()
        if (bluetoothAdapter == null) {
        	doNotSupport = true
   			new AlertDialog.Builder(this)
                	    .setTitle("Error")
                	    .setMessage("Bluetooth Not Supported")
                	    .setNeutralButton(android.R.string.ok, new DialogInterface.OnClickListener() {
                	        override onClick(DialogInterface dialog, int which) { 
                	        	// do nothing
                	        }
                	     })
                	    .setIcon(android.R.drawable.ic_dialog_alert)
                	    .show()
  		} else {
   			if (!bluetoothAdapter.isEnabled()) {
   				Log.i(getString(R.string.LOGTAG), "ask to enable BT")
				startActivityForResult(new Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE), 42)
				doNotSupport = true
   			}
  		}
    	
    	if (doNotSupport == false) {
    		PreferenceManager.setDefaultValues(this, R.xml.preferences, false)
        	startService(new Intent(this, typeof(BLEService)))
        	registerReceiver(mServiceActionReceiver, serviceActionIntentFilter())
        	Log.i(getString(R.string.LOGTAG), "MainActivity start BLEService")
        }
        Log.i(getString(R.string.LOGTAG), "MainActivity onCreate")
    }
    
    override onActivityResult(int requestCode, int resultCode, Intent data) {
    	if (requestCode == 42) {
        	if (resultCode == RESULT_OK) {
        		doNotSupport = false
    			PreferenceManager.setDefaultValues(this, R.xml.preferences, false)
        		startService(new Intent(this, typeof(BLEService)))
        		registerReceiver(mServiceActionReceiver, serviceActionIntentFilter())
        		Log.i(getString(R.string.LOGTAG), "MainActivity start BLEService")        		
        	}
    	}
	}
	
	override onDestroy() {
		Log.i(getString(R.string.LOGTAG), "MainActivity onDestroy")
		if (doNotSupport == false) {
    		unregisterReceiver(mServiceActionReceiver)	
    	}		
    	super.onDestroy()
    }
    
	// Button's cfgSettings method
	override cfgSettings(View v) {
		if (doNotSupport == false) {
    		startActivity(new Intent(this, typeof(SettingsActivity)))
    	}
	}
	
	// Button's loadDevs method
	override loadDevs(View v) {
		if (doNotSupport == false) {
    		startActivity(new Intent(this, typeof(DeviceListActivity)))
    	}
	}

	// Button's plot method
	override plot(View v) {
		if (doNotSupport == false) {
    		startActivity(new Intent(this, typeof(PlotActivity)))
    	}
	}

	var BroadcastReceiver mServiceActionReceiver = new BroadcastReceiver() {
		override onReceive(Context context, Intent intent) {
			if (intent.getAction().equals(getString(R.string.ACTION_UPDATE_TEMP))) {
        		runOnUiThread[
        			var IPC p = intent.getParcelableExtra(getString(R.string.ACTION_EXTRA))
					//var sb = new StringBuilder(p.data.length * 3)
        			//for (byte b: p.data) {
        			//	sb.append(String.format("%02x ", b));
        			//}
        			//Log.i(getString(R.string.LOGTAG), "MainActivity got Notification: " + sb.toString());
        							
					var tempUnit = PreferenceManager?.getDefaultSharedPreferences(selfActivity)?.getString("temp_unit_selection", "C_TYPE")
					currentTemp.text = Utils.getTempType(p.data, tempUnit)
				]
			} else if (intent.getAction().equals(getString(R.string.ACTION_STOP))) {
				finish()
			}
		}
	}
	
	def serviceActionIntentFilter() {
		var intentFilter = new IntentFilter()
		intentFilter.addAction(getString(R.string.ACTION_UPDATE_TEMP))
		intentFilter.addAction(getString(R.string.ACTION_STOP))
		return intentFilter
	}
	
}