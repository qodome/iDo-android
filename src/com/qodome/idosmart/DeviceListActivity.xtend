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
import android.widget.ListView
import android.widget.AdapterView.OnItemClickListener
import android.widget.AdapterView

@Accessors class DevElementView {
  String deviceListElemName
  String deviceListElemAddr
}

@AndroidActivity(R.layout.activity_device_list) class DeviceListActivity {
	var devListActivity = this
	var IPC devListAvailableInfo
	var IPC devListConnectedInfo

	def updateUIList(Intent intent, ListView view) {
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
			view.adapter = adapter
		]
	}

	var BroadcastReceiver mServiceActionReceiver = new BroadcastReceiver() {
		override onReceive(Context context, Intent intent) {
			if (intent.getAction().equals(getString(R.string.ACTION_RSP_DEV_LIST_AVAILABLE))) {
				updateUIList(intent, deviceListAvailable)
				devListAvailableInfo = intent.getParcelableExtra(getString(R.string.ACTION_EXTRA))
				deviceListAvailable.setOnItemClickListener(new OnItemClickListener() {
          			override onItemClick(AdapterView<?> parent, View view, int position, long id) {
						var p = new IPC
						p.devAddr = new ArrayList<String>()
						p.devAddr.add(devListAvailableInfo.devAddr.get(position))
						sendBroadcast(new Intent(getString(R.string.ACTION_CONNECT_TO_DEVICE)).putExtra(getString(R.string.ACTION_EXTRA), p))
              		}
            	})
			} else if (intent.getAction().equals(getString(R.string.ACTION_RSP_DEV_LIST_CONNECTED))) {
				updateUIList(intent, deviceListConnected)
				devListConnectedInfo = intent.getParcelableExtra(getString(R.string.ACTION_EXTRA))
				deviceListConnected.setOnItemClickListener(new OnItemClickListener() {
          			override onItemClick(AdapterView<?> parent, View view, int position, long id) {
						startActivity(new Intent(devListActivity, typeof(DeviceDetailActivity)))
              		}
            	})
			} 
		}
	}
	
	def serviceActionIntentFilter() {
		var intentFilter = new IntentFilter()
		intentFilter.addAction(getString(R.string.ACTION_RSP_DEV_LIST_AVAILABLE))
		intentFilter.addAction(getString(R.string.ACTION_RSP_DEV_LIST_CONNECTED))
		return intentFilter
	}

	@OnCreate
    def init(Bundle savedInstanceState) {
    	registerReceiver(mServiceActionReceiver, serviceActionIntentFilter())
        queryDevList()
        Log.i(getString(R.string.LOGTAG), "start scan")
    }

	override onDestroy() {
    	unregisterReceiver(mServiceActionReceiver)
    	sendBroadcast(new Intent(getString(R.string.ACTION_STOP_SCAN)))
    	Log.i(getString(R.string.LOGTAG), "stop scan")
    	super.onDestroy()
    }

	def queryDevList() {
		sendBroadcast(new Intent(getString(R.string.ACTION_REQ_DEV_LIST_AVAILABLE)))
		sendBroadcast(new Intent(getString(R.string.ACTION_REQ_DEV_LIST_CONNECTED)))
	}
}