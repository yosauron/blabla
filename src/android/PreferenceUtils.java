//
//  MessageActivity.java
//
// Pushwoosh Push Notifications SDK
// www.pushwoosh.com
//
// MIT Licensed

package com.arellomobile.android.push;

import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;

public class PreferenceUtils
{
    private static final String PREFERENCE = "com.google.android.c2dm";

    public static final String LAST_REGISTRATION_CHANGE = "last_registration_change";
    public static final String BACKOFF = "backoff";
    private static final long DEFAULT_BACKOFF = 30000;

    public static String getSenderId(Context context)
    {
        final SharedPreferences prefs = context.getSharedPreferences(PREFERENCE, Context.MODE_PRIVATE);
        return prefs.getString("dm_sender_id", "");
    }

    public static void setSenderId(Context context, String senderId)
    {
        final SharedPreferences prefs = context.getSharedPreferences(PREFERENCE, Context.MODE_PRIVATE);
        final SharedPreferences.Editor editor = prefs.edit();
        editor.putString("dm_sender_id", senderId);
        editor.commit();
    }

    public static long getLastRegistrationChange(Context context) {
        final SharedPreferences prefs = context.getSharedPreferences(PREFERENCE, Context.MODE_PRIVATE);
        return prefs.getLong(LAST_REGISTRATION_CHANGE, 0);
    }

    public static void setApplicationId(Context context, String applicationId) {
        final SharedPreferences prefs = context.getSharedPreferences(PREFERENCE, Context.MODE_PRIVATE);
        SharedPreferences.Editor editor = prefs.edit();
        editor.putString("dm_pwapp", applicationId);
        editor.commit();
    }

    public static String getApplicationId(Context context) {
        final SharedPreferences prefs = context.getSharedPreferences(PREFERENCE, Context.MODE_PRIVATE);
        String applicationId = prefs.getString("dm_pwapp", "");
        return applicationId;
    }
}
