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
import android.widget.AdapterView.OnItemLongClickListener
import android.widget.AdapterView
import android.widget.ProgressBar
import android.app.AlertDialog
import android.content.DialogInterface

@Accessors class DevElementView {
  String deviceListElemName
  String deviceListElemAddr
  String connectProgressBar
}

@AndroidActivity(R.layout.activity_device_list) class DeviceListActivity {
	var devListActivity = this
	var IPC devListAvailableInfo
	var String connCandidate = null

	var BroadcastReceiver mServiceActionReceiver = new BroadcastReceiver() {
		override onReceive(Context context, Intent intent) {
			if (intent.getAction().equals(getString(R.string.ACTION_RSP_DEV_LIST_AVAILABLE))) {
				
				runOnUiThread[
				// Populate the list
				var IPC p = intent.getParcelableExtra(getString(R.string.ACTION_EXTRA))
				var List<DevElementView> devList = new ArrayList<DevElementView>()
				for (var i = 0; i < p.devAddr.size(); i++) {
					var devElem = new DevElementView()
					devElem.deviceListElemName = p.devName.get(i)
					devElem.deviceListElemAddr = p.devAddr.get(i)
					devElem.connectProgressBar = "gone"
					if (connCandidate != null) {
						if (connCandidate.equals(p.devAddr.get(i))) {
							devElem.connectProgressBar = "visible"
						}
					}
					devList.add(devElem)
				}
				var adapter = new BeanAdapter<DevElementView>(devListActivity, R.layout.element_device_list, devList)
				deviceListAvailable.adapter = adapter
				]
				
				devListAvailableInfo = intent.getParcelableExtra(getString(R.string.ACTION_EXTRA))
				deviceListAvailable.setOnItemClickListener(new OnItemClickListener() {
          			override onItemClick(AdapterView<?> parent, View view, int position, long id) {
						var p = new IPC
						p.devAddr = new ArrayList<String>()
						p.devAddr.add(devListAvailableInfo.devAddr.get(position))
						sendBroadcast(new Intent(getString(R.string.ACTION_CONNECT_TO_DEVICE)).putExtra(getString(R.string.ACTION_EXTRA), p))
              			var progress = view.findViewById(R.id.connect_progress_bar) as ProgressBar
						progress.setVisibility(View.VISIBLE)
						connCandidate = devListAvailableInfo.devAddr.get(position)
              		}
            	})
			} else if (intent.getAction().equals(getString(R.string.ACTION_RSP_DEV_LIST_CONNECTED))) {
				connCandidate = null
				
				runOnUiThread[
				// Populate the list
				var IPC p = intent.getParcelableExtra(getString(R.string.ACTION_EXTRA))
				var List<DevElementView> devList = new ArrayList<DevElementView>()
				var devElem = new DevElementView()
				if (p.devAddr.get(0) == "NOT_CONNECTED") {
					devElem.deviceListElemName = ""
					devElem.deviceListElemAddr = ""
					devElem.connectProgressBar = "gone"
					devList.add(devElem)
				} else {
					devElem.deviceListElemName = p.devName.get(0)
					devElem.deviceListElemAddr = p.devAddr.get(0)
					if (p.devConnStatus == "transit") {
						devElem.connectProgressBar = "visible"
					} else {
						devElem.connectProgressBar = "gone"
					}
					devList.add(devElem)					
				}	
				var adapter = new BeanAdapter<DevElementView>(devListActivity, R.layout.element_device_list, devList)
				deviceListConnected.adapter = adapter
				]
				
				var IPC p = intent.getParcelableExtra(getString(R.string.ACTION_EXTRA))
				if (p.devAddr.get(0) != "NOT_CONNECTED" && p.devConnStatus != "transit") {
					deviceListConnected.setOnItemClickListener(new OnItemClickListener() {
          				override onItemClick(AdapterView<?> parent, View view, int position, long id) {
							startActivity(new Intent(devListActivity, typeof(DeviceDetailActivity)))
              			}
            		})
            		deviceListConnected.setOnItemLongClickListener(new OnItemLongClickListener() {
          				override onItemLongClick(AdapterView<?> parent, View view, int position, long id) {
							// Wait for action confirm to disconnect current device
							new AlertDialog.Builder(devListActivity)
                	    	.setTitle("Confirmation")
                	    	.setMessage("Disconnect with device?")
                	    	.setNeutralButton(android.R.string.ok, new DialogInterface.OnClickListener() {
                	    		override onClick(DialogInterface dialog, int which) { 
                	        		sendBroadcast(new Intent(getString(R.string.ACTION_DISCONNECT)))
                	        	}
                	     	})
                	    	.setIcon(android.R.drawable.ic_dialog_alert)
                	    	.show()
							return true
              			}
            		})					
				}
			} else if (intent.getAction().equals(getString(R.string.ACTION_STOP))) {
				finish()
			} 
		}
	}
	
	def serviceActionIntentFilter() {
		var intentFilter = new IntentFilter()
		intentFilter.addAction(getString(R.string.ACTION_RSP_DEV_LIST_AVAILABLE))
		intentFilter.addAction(getString(R.string.ACTION_RSP_DEV_LIST_CONNECTED))
		intentFilter.addAction(getString(R.string.ACTION_STOP))
		return intentFilter
	}

	@OnCreate
    def init(Bundle savedInstanceState) {
    	connCandidate = null
    	registerReceiver(mServiceActionReceiver, serviceActionIntentFilter())
        queryDevList()
        Log.i(getString(R.string.LOGTAG), "start scan")
        
        var List<DevElementView> devList = new ArrayList<DevElementView>()
		var devElem = new DevElementView()
		devElem.deviceListElemName = ""
		devElem.deviceListElemAddr = ""
		devElem.connectProgressBar = "gone"
		devList.add(devElem)
		deviceListConnected.adapter = new BeanAdapter<DevElementView>(devListActivity, R.layout.element_device_list, devList)
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