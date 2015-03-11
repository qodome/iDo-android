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

@AndroidActivity(R.layout.activity_main) class MainActivity {
	var selfActivity = this

	@OnCreate
    def init(Bundle savedInstanceState) {
    	PreferenceManager.setDefaultValues(this, R.xml.preferences, false)
        startService(new Intent(this, typeof(BLEService)))
        registerReceiver(mServiceActionReceiver, serviceActionIntentFilter())
        Log.i(getString(R.string.LOGTAG), "iDoSmart start BLEService")
    }
	
	override onDestroy() {
    	unregisterReceiver(mServiceActionReceiver)
    	super.onDestroy()
    }
	
	// Button's cfgSettings method
	override cfgSettings(View v) {
    	startActivity(new Intent(this, typeof(SettingsActivity)))
	}
	
	// Button's loadDevs method
	override loadDevs(View v) {
    	startActivity(new Intent(this, typeof(DeviceListActivity)))
	}

	// Button's plot method
	override plot(View v) {
    	startActivity(new Intent(this, typeof(PlotActivity)))
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
			}
		}
	}
	
	def serviceActionIntentFilter() {
		var intentFilter = new IntentFilter()
		intentFilter.addAction(getString(R.string.ACTION_UPDATE_TEMP))
		return intentFilter
	}
	
}