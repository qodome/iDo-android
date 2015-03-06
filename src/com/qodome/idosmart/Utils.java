package com.qodome.idosmart;

import java.util.Calendar;
import java.util.TimeZone;

public class Utils {
	public static byte[] getCalendarTime() {
        Calendar c = Calendar.getInstance(TimeZone.getTimeZone("UTC")); 
        int year = c.get(Calendar.YEAR);
        int month = c.get(Calendar.MONTH) + 1;
        int day = c.get(Calendar.DAY_OF_MONTH);
        int hour = c.get(Calendar.HOUR_OF_DAY);
        int minute = c.get(Calendar.MINUTE);
        int second = c.get(Calendar.SECOND);
        byte[] t = new byte[7];
        t[0] = (byte)(year & 0xFF);
        t[1] = (byte)(year >> 8);
        t[2] = (byte)month;
        t[3] = (byte)day;
        t[4] = (byte)hour;
        t[5] = (byte)minute;
        t[6] = (byte)second;
        return t;
	}
}
