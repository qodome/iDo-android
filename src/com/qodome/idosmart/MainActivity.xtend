package com.qodome.idosmart

import android.view.View
import org.xtendroid.app.AndroidActivity
import android.os.Bundle
import org.xtendroid.app.OnCreate
import android.content.Intent

@AndroidActivity(R.layout.activity_main) class MainActivity {

	@OnCreate
    def init(Bundle savedInstanceState) {
        startService(new Intent(this, typeof(BLEService)))
    }
	
	// Button's cfgSettings method
	override cfgSettings(View v) {
    	startActivity(new Intent(this, typeof(SettingsActivity)))
	}
	
	// Button's loadDevs method
	override loadDevs(View v) {
    	startActivity(new Intent(this, typeof(DeviceListActivity)))
	}
		
}