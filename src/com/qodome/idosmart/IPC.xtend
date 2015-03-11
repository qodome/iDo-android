package com.qodome.idosmart

import java.util.List
import org.xtendroid.parcel.AndroidParcelable

@AndroidParcelable
class IPC {
    public List<String> devAddr
    public List<String> devName 
    public byte[] data
    public String oadCurrent
    public String oadTarget
    public String oadStatus   
    public String colorSetting 

    override toString() {
        '''«devAddr», «devName», «data», «oadCurrent», «oadTarget», «oadStatus», «colorSetting»'''
    }
}