package com.qodome.idosmart

import android.view.View
import org.xtendroid.app.AndroidActivity
import android.os.Bundle
import org.xtendroid.app.OnCreate
import android.content.Intent
import com.qodome.idosmart.IPC
import android.util.Log
import android.content.BroadcastReceiver
import android.content.IntentFilter
import android.content.Context
import org.eclipse.xtend.lib.annotations.Accessors
import java.util.List
import java.util.ArrayList
import org.xtendroid.adapter.BeanAdapter

@Accessors class DevElementView {
  String deviceListElemName
  String deviceListElemAddr
}

@AndroidActivity(R.layout.activity_device_list) class DeviceListActivity {
	var devListActivity = this

	var BroadcastReceiver mServiceActionReceiver = new BroadcastReceiver() {
		override onReceive(Context context, Intent intent) {
			if (intent.getAction().equals(getString(R.string.ACTION_RSP_DEV_LIST))) {
				runOnUiThread[
				// Populate the list
				var IPC p = intent.getParcelableExtra(getString(R.string.ACTION_EXTRA))
				
				var List<DevElementView> devList = new ArrayList<DevElementView>()
				for (var i = 0; i < p.devAddr.size(); i++) {
					var devElem = new DevElementView()
					devElem.deviceListElemName = p.devName.get(i)
					devElem.deviceListElemAddr = p.devAddr.get(i)
					devList.add(devElem)
				}
				var adapter = new BeanAdapter<DevElementView>(devListActivity, R.layout.element_device_list, devList)
				deviceList.adapter = adapter
				]
			}
		}
	}
	
	def serviceActionIntentFilter() {
		var intentFilter = new IntentFilter();
		intentFilter.addAction(getString(R.string.ACTION_RSP_DEV_LIST));
		return intentFilter;
	}

	@OnCreate
    def init(Bundle savedInstanceState) {
    	registerReceiver(mServiceActionReceiver, serviceActionIntentFilter())
        queryDevList()
    }

	override onDestroy() {
    	unregisterReceiver(mServiceActionReceiver)
    	super.onDestroy()
    }

	def queryDevList() {
		var intent = new Intent(getString(R.string.ACTION_REQ_DEV_LIST))
		Log.i(getString(R.string.LOGTAG), "sendBroadcast")
		sendBroadcast(intent)
	}
}