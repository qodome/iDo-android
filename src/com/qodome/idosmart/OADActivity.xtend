package com.qodome.idosmart

import org.xtendroid.app.AndroidActivity
import org.xtendroid.app.OnCreate
import android.os.Bundle
import android.content.Intent
import android.content.IntentFilter
import android.content.BroadcastReceiver
import android.content.Context

@AndroidActivity(R.layout.activity_oad) class OADActivity {

	var BroadcastReceiver mServiceActionReceiver = new BroadcastReceiver() {
		override onReceive(Context context, Intent intent) {
			var IPC p = intent.getParcelableExtra(getString(R.string.ACTION_EXTRA))
			if (intent.getAction().equals(getString(R.string.ACTION_OAD_VERSION))) {
				oadCurrentVersion.text = p.oadCurrent
				oadTargetVersion.text = p.oadTarget
			} else if (intent.getAction().equals(getString(R.string.ACTION_OAD_STATUS))) {
				oadProgress.text = p.oadStatus
			} 
		}
	}
	
	def serviceActionIntentFilter() {
		var intentFilter = new IntentFilter()
		intentFilter.addAction(getString(R.string.ACTION_OAD_STATUS))
		intentFilter.addAction(getString(R.string.ACTION_OAD_VERSION))
		return intentFilter
	}

	@OnCreate
    def init(Bundle savedInstanceState) {
    	registerReceiver(mServiceActionReceiver, serviceActionIntentFilter())
        startService(new Intent(this, typeof(OADService)))
        
        oadCurrentVersion.text = OADService.currentVersion
        oadTargetVersion.text = OADService.targetVersion
        oadProgress.text = OADService.oadStatus
    }
    
	override onDestroy() {
    	unregisterReceiver(mServiceActionReceiver)
    	super.onDestroy()
    }
}