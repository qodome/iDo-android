package com.qodome.idosmart

import java.util.List
import org.xtendroid.parcel.AndroidParcelable

@AndroidParcelable
class IPC {
    public List<String> devAddr
    public List<String> devName 
    public byte[] data

    override toString() {
        '''«devAddr», «devName», «data»'''
    }
}