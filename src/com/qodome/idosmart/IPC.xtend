package com.qodome.idosmart

import java.util.List
import org.xtendroid.parcel.AndroidParcelable

@AndroidParcelable
class IPC {
    public List<String> devAddr
    public List<String> devName
    public String devConnStatus		// "transit" - during connection setup
    								// "solid" - the connection status is solid
    public byte[] data				// Temperature data BLEService sent to MainActivity
    public String oadCurrent		// Current firmware version
    public String oadTarget			// Candidate firmware version
    public String oadStatus   		// OAD progress
    public String colorSetting		// BLEService notify MainActivity about background color

    override toString() {
        '''«devAddr», «devName», «devConnStatus», «data», «oadCurrent», «oadTarget», «oadStatus», «colorSetting»'''
    }
}