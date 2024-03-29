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
import com.tyczj.extendedcalendarview.Day
import android.widget.AdapterView
import android.view.View
import com.github.mikephil.charting.charts.LineChart
import java.util.ArrayList
import com.github.mikephil.charting.data.Entry
import com.github.mikephil.charting.data.LineDataSet
import android.graphics.Color
import com.github.mikephil.charting.utils.ColorTemplate
import com.github.mikephil.charting.data.LineData
import org.json.JSONArray
import com.google.common.io.CharStreams
import java.io.InputStreamReader
import java.io.FileInputStream
import com.google.common.base.Charsets
import android.preference.PreferenceManager

@AndroidActivity(R.layout.activity_plot) class PlotActivity {
	var ExtendedCalendarView calendar
	val final SECONDS_OF_DAY = 86400

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
				addRecords2Calendar(Integer.parseInt(fields.get(0)), (Integer.parseInt(fields.get(1)) - 1), Integer.parseInt(fields.get(2)))
			}
		}
		
		calendar.setOnDayClickListener(new ExtendedCalendarView.OnDayClickListener(){
            override onDayClicked(AdapterView<?> adapter, View view, int position, long id, Day day) {
                plotRecord(day.year, (day.month + 1), day.day)
            }
		})
    }
    
    def addRecords2Calendar(int year, int month, int day) {
		var values = new ContentValues()
    	values.put(CalendarProvider.COLOR, Event.COLOR_RED)
    	values.put(CalendarProvider.DESCRIPTION, "Temperature records")
    	values.put(CalendarProvider.LOCATION, "")
    	values.put(CalendarProvider.EVENT, "TEMP")

    	var cal = Calendar.getInstance(TimeZone.getTimeZone("UTC"))

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
    
    def plotRecord(int year, int month, int day) {
    	var mChart =  findViewById(R.id.chart) as LineChart
    	var fn = new File(Environment.getExternalStorageDirectory().getAbsolutePath() + "/iDoSmart/" +
    					year + "_" + month + "_" + day + ".json")
		if (fn.exists()) {
        	val count = SECONDS_OF_DAY / BLEService.HISTORY_STATS_SECONDS
        	
        	mChart.setDescription("")
        	mChart.setHighlightEnabled(true)
        	mChart.setTouchEnabled(true)
        	mChart.setDragEnabled(true)
        	mChart.setScaleEnabled(true)
        	mChart.setPinchZoom(false)
        	mChart.setDrawGridBackground(false)
        	
       		var xVals = new ArrayList<String>();
        	for (var i = 0; i < 24; i++) {
            	xVals.add(i + ":00")
            	xVals.add(i + ":05")
            	for (var j = 2; j < 12; j++) {
            		xVals.add(i + ":" + (j * 5))
            	
        		}
        	}

			var valCount = 0
        	var vals1 = new ArrayList<Entry>();
        	
        	// Read JSON from file, do the merge
			var dataString = CharStreams.toString(new InputStreamReader(new FileInputStream(fn), Charsets.UTF_8))
			var JSONArray dataArray
			if (dataString.length() > 0) {
				dataArray = new JSONArray(dataString)
				var elem = dataArray.getJSONArray(0) as JSONArray
				var startTime = elem.getInt(0)
				val remain = (startTime % SECONDS_OF_DAY) / BLEService.HISTORY_STATS_SECONDS
				for (var i = 0; i < remain && valCount < count; i++) {
            		var value = 0.0f
            		vals1.add(new Entry(value, i))
            		valCount++
        		}
        		val tempType = PreferenceManager?.getDefaultSharedPreferences(this)?.getString("temp_unit_selection", "C_TYPE")
        		for (var i = remain; i < (remain + dataArray.length()) && valCount < count; i++) {
        			var float value
        			if (!dataArray.getJSONArray((i - remain)).isNull(1)) {
        				value = Utils.getTempType(dataArray.getJSONArray((i - remain)).getDouble(1), tempType) as float
        			} else {
        				value = 0.0f
        			}
            		vals1.add(new Entry(value, i));
            		valCount++
        		}
			} else {
				for (var i = 0; i < 1 && valCount < count; i++) {
            		var value = 0.0f
            		vals1.add(new Entry(value, i))
            		valCount++
        		}
			}
	       
        	var set1 = new LineDataSet(vals1, "DataSet 1");
        	set1.setDrawCubic(false);
        	set1.setDrawFilled(false);
        	set1.setDrawCircles(false);
        	set1.setLineWidth(1f);
        	//set1.setCircleSize(5f);
        	set1.setHighLightColor(Color.rgb(244, 117, 117));
        	set1.setColor(Color.rgb(104, 241, 175));
        	//set1.setFillColor(ColorTemplate.getHoloBlue());
        	var data = new LineData(xVals, set1)
        	data.setValueTextSize(9f)
        	data.setDrawValues(true)
        	mChart.setData(data)
        
        	mChart.getLegend().setEnabled(false)
        	mChart.animateX(2000)
        	mChart.invalidate()		// Ask to draw itself
    	} else {
    		mChart.clear()
    	}
    }
}