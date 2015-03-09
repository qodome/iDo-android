package com.qodome.idosmart

import org.xtendroid.app.AndroidActivity
import org.xtendroid.app.OnCreate
import android.os.Bundle
import android.widget.CalendarView
import com.tyczj.extendedcalendarview.ExtendedCalendarView
import com.tyczj.extendedcalendarview.CalendarProvider
import android.content.ContentValues
import com.tyczj.extendedcalendarview.Event
import java.util.Calendar
import java.util.TimeZone
import android.text.format.Time
import java.util.concurrent.TimeUnit
import java.io.File
import android.os.Environment
import android.util.Log

@AndroidActivity(R.layout.activity_plot) class PlotActivity {
	var ExtendedCalendarView calendar

	@OnCreate
    def init(Bundle savedInstanceState) {
		calendar = findViewById(R.id.calendar) as ExtendedCalendarView

		// Loop over temperature log folder to find out valid records
		var dir = new File(Environment.getExternalStorageDirectory().getAbsolutePath() + "/" + "iDoSmart")        
		var files = dir.listFiles() as File[]
		for (var i=0; i < files.length; i++) {
			if (files.get(i).getName().contains(".json")) {
				var fields = files.get(i).getName().split(".json") as String[]
				fields = fields.get(0).split("_")
				addRecords2Calendar(Integer.parseInt(fields.get(0)), Integer.parseInt(fields.get(1)), Integer.parseInt(fields.get(2)))
			}
		}
    }
    
    def addRecords2Calendar(int year, int month, int day) {
		var values = new ContentValues()
    	values.put(CalendarProvider.COLOR, Event.COLOR_RED)
    	values.put(CalendarProvider.DESCRIPTION, "Temperature records")
    	values.put(CalendarProvider.LOCATION, "")
    	values.put(CalendarProvider.EVENT, "TEMP")

    	var cal = Calendar.getInstance()

    	cal.set(year, month, day, 0, 0);
    	values.put(CalendarProvider.START, cal.getTimeInMillis());
    	values.put(CalendarProvider.START_DAY, Time.getJulianDay(cal.getTimeInMillis(), 0))
    	var tz = TimeZone.getDefault();

    	cal.set(year, month, day, 23, 59);
    	var endDayJulian = Time.getJulianDay(cal.getTimeInMillis(), 0)

    	values.put(CalendarProvider.END, cal.getTimeInMillis());
    	values.put(CalendarProvider.END_DAY, endDayJulian);

    	var uri = getContentResolver().insert(CalendarProvider.CONTENT_URI, values);    	
    }
}