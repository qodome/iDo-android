package com.qodome.idosmart

import org.xtendroid.app.AndroidActivity
import android.os.Bundle
import org.xtendroid.app.OnCreate
import org.eclipse.xtend.lib.annotations.Accessors
import java.util.List
import java.util.ArrayList
import org.xtendroid.adapter.BeanAdapter

@Accessors class DevDetailElement {
	String deviceDetailKey
	String deviceDetailValue
}

@AndroidActivity(R.layout.activity_device_detail) class DeviceDetailActivity {
	
	@OnCreate
    def init(Bundle savedInstanceState) {
    	BLEService.ddActivity = this
    	
    	var List<DevDetailElement> devList = new ArrayList<DevDetailElement>()
    	var devElem = new DevDetailElement()
    	devElem.deviceDetailKey = "Name"
    	devElem.deviceDetailValue = BLEService.mDevice?.getName()
    	devList.add(devElem)
    	devElem = new DevDetailElement()
    	devElem.deviceDetailKey = ""
    	devElem.deviceDetailValue = ""
    	deviceDetailHead.adapter = new BeanAdapter<DevDetailElement>(this, R.layout.element_device_detail, devList)
    }

	override onDestroy() {
    	BLEService.ddActivity = null
    	super.onDestroy()
    }	
}