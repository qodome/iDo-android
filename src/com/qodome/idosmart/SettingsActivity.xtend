package com.qodome.idosmart

import android.view.View
import org.xtendroid.app.AndroidActivity
import android.os.Bundle
import org.xtendroid.app.OnCreate
import android.content.Intent
import android.widget.ArrayAdapter
import android.preference.PreferenceFragment

public class SettingsFragment extends PreferenceFragment {
    override onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState)
        addPreferencesFromResource(R.xml.preferences)
    }
}

@AndroidActivity(R.layout.activity_settings) class SettingsActivity {

	override onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        getFragmentManager().beginTransaction()
                .replace(android.R.id.content, new SettingsFragment())
                .commit();
    }
}