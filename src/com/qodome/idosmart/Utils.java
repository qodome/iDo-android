package com.qodome.idosmart;

import java.util.Calendar;
import java.util.TimeZone;
import java.lang.Math;
import java.math.BigDecimal;
import java.math.RoundingMode;

import android.util.Log;

public class Utils {
	public static byte[] bytes;
	
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
	
	public static double round(double value, int places) {
	    if (places < 0) throw new IllegalArgumentException();

	    BigDecimal bd = new BigDecimal(value);
	    bd = bd.setScale(places, RoundingMode.HALF_UP);
	    return bd.doubleValue();
	}

	public static double getTempC(byte[] b) {
		double d = 0.0;
		int i = 0;
		
		i = b[3] * 256 * 256 + b[2] * 256 + b[1];
		d = (double)i / 10000.0;
		return round(d, 1);
	}	
	
	public static String getTempType(byte[] b, String tempUnitCfg) {
		double d = 0.0;
		int i = 0;
		String ret = new String("");
		
		i = b[3] * 256 * 256 + b[2] * 256 + b[1];
		d = (double)i / 10000.0;
		if (tempUnitCfg.endsWith("F_TYPE")) {
			// Parse temperature as F
			d = round((d * 1.8 + 32.0), 1);
			ret = new String(String.valueOf(d) + "°F");
		} else if (tempUnitCfg.endsWith("K_TYPE")) {
			// Parse temperature as K
			d = round((d + 273.15), 1);
			ret = new String(String.valueOf(d) + "K");
		} else {
			// Parse temperature as C
			d = round(d, 1);
			ret = new String(String.valueOf(d) + "°C");
		}
		return ret;
	}

	public static double getTempType(double d, String tempUnitCfg) {
		if (tempUnitCfg.endsWith("F_TYPE")) {
			// Parse temperature as F
			d = round((d * 1.8 + 32.0), 1);
		} else if (tempUnitCfg.endsWith("K_TYPE")) {
			// Parse temperature as K
			d = round((d + 273.15), 1);
		}
		return d;
	}
	
	public static byte[] parepareBlock(int idx, byte[] b) {
		byte[] c = new byte[2 + b.length];
		c[0] = (byte)(idx & 0xFF);
		c[1] = (byte)((idx & 0xFF00) >> 8);
		System.arraycopy(b, 0, c, 2, b.length);
		return c;
	}
	
	public static int getWriteIdx(byte[] b) {
		return ((int)b[1] << 8) | (int)b[0];
	}
}
