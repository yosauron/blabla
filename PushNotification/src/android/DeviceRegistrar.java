//
//  DeviceRegistrar.java
//
// Pushwoosh Push Notifications SDK
// www.pushwoosh.com
//
// MIT Licensed

package com.arellomobile.android.push;

import android.content.Context;
import android.content.SharedPreferences;
import android.content.res.Configuration;
import android.provider.Settings;
import android.telephony.TelephonyManager;
import android.util.Log;
import com.google.android.gcm.GCMRegistrar;
import org.json.JSONObject;

import java.io.BufferedInputStream;
import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.*;

/**
 * Register/unregister with the App server.
 */
public class DeviceRegistrar
{
    private static final String TAG = "DeviceRegistrar";

    private static final int MAX_TRIES = 5;

    private static final String BASE_URL = "https://cp.pushwoosh.com/json";

    private static final String REGISTER_PATH = "/1.2/registerDevice";
    private static final String UNREGISTER_PATH = "/1.2/unregisterDevice";

    private static final String SHARED_KEY = "deviceid";
    private static final String SHARED_PREF_NAME = "com.arellomobile.android.push.deviceid";

    static void registerWithServer(final Context context, final String deviceRegistrationID)
    {
        int res = 0;
        Exception exception = new Exception();
        for (int i = 0; i < MAX_TRIES; ++i)
        {
            try
            {
                res = makeRequest(context, deviceRegistrationID, REGISTER_PATH);
                if (200 == res)
                {
                    GCMRegistrar.setRegisteredOnServer(context, true);
                    PushEventsTransmitter.onRegistered(context, deviceRegistrationID);
                    Log.w(TAG, "Registered for pushes: " + deviceRegistrationID);
                    return;
                }
            } catch (Exception e)
            {
                exception = e;
            }
        }

        PushEventsTransmitter.onRegisterError(context, "status code is " + res + "\n error: " + exception.getMessage());
        Log.w(TAG, "Registration error " + exception.getMessage());
    }

    static void unregisterWithServer(final Context context, final String deviceRegistrationID)
    {
        GCMRegistrar.setRegisteredOnServer(context, false);

        int res;
        Exception exception = new Exception();
        for (int i = 0; i < MAX_TRIES; ++i)
        {
            try
            {
                res = makeRequest(context, deviceRegistrationID, UNREGISTER_PATH);
                if (200 == res)
                {
                    PushEventsTransmitter.onUnregistered(context, deviceRegistrationID);
                    Log.w(TAG, "Unregistered for pushes: " + deviceRegistrationID);
                    return;
                }
            } catch (Exception e)
            {
                exception = e;
            }
        }

        PushEventsTransmitter.onUnregisteredError(context, exception.getMessage());
        Log.w(TAG, "Unregistration error " + exception.getMessage());
    }

    private static int makeRequest(Context context, String deviceRegistrationID, String urlPath) throws Exception
    {
        int result = 500;
        OutputStream connectionOutput = null;
        InputStream inputStream = null;
        try
        {
            URL url = new URL(BASE_URL + urlPath);
            HttpURLConnection connection = (HttpURLConnection) url.openConnection();
            connection.setRequestMethod("POST");
            connection.setRequestProperty("Content-Type", "application/json; charset=utf-8");

            connection.setDoOutput(true);


            JSONObject innerRequestJson = new JSONObject();

            String deviceId = getDeviceUUID(context);
            innerRequestJson.put("hw_id", deviceId);

            Locale locale = Locale.getDefault();
            String language = locale.getLanguage();

            innerRequestJson.put("device_name", isTablet(context) ? "Tablet" : "Phone");
            innerRequestJson.put("application", PreferenceUtils.getApplicationId(context));
            innerRequestJson.put("device_type", "3");
            innerRequestJson.put("device_id", deviceRegistrationID);
            innerRequestJson.put("language", language);
            innerRequestJson.put("timezone",
                                 Calendar.getInstance().getTimeZone()
                                         .getRawOffset() / 1000); // converting from milliseconds to seconds

            JSONObject requestJson = new JSONObject();
            requestJson.put("request", innerRequestJson);

            connection.setRequestProperty("Content-Length", String.valueOf(requestJson.toString().getBytes().length));

            connectionOutput = connection.getOutputStream();
            connectionOutput.write(requestJson.toString().getBytes());
            connectionOutput.flush();
            connectionOutput.close();

            inputStream = new BufferedInputStream(connection.getInputStream());

            ByteArrayOutputStream dataCache = new ByteArrayOutputStream();

            // Fully read data
            byte[] buff = new byte[1024];
            int len;
            while ((len = inputStream.read(buff)) >= 0)
            {
                dataCache.write(buff, 0, len);
            }

            result = connection.getResponseCode();
            // Close streams
            dataCache.close();

            String jsonString = new String(dataCache.toByteArray()).trim();
        } finally
        {
            if (null != inputStream)
            {
                inputStream.close();
            }
            if (null != connectionOutput)
            {
                connectionOutput.close();
            }
        }

        return result;
    }

    private static List<String> sWrongAndroidDevices;

    static
    {
        sWrongAndroidDevices = new ArrayList<String>();

        sWrongAndroidDevices.add("9774d56d682e549c");
    }

    private static String getDeviceUUID(Context context)
    {
        final String androidId = Settings.Secure.getString(context.getContentResolver(), Settings.Secure.ANDROID_ID);
        // see http://code.google.com/p/android/issues/detail?id=10603
        if (null != androidId && !sWrongAndroidDevices.contains(androidId))
        {
            return androidId;
        }
        try
        {
            final String deviceId = ((TelephonyManager) context.getSystemService(Context.TELEPHONY_SERVICE))
                    .getDeviceId();
            if (null != deviceId)
            {
                return deviceId;
            }
        } catch (RuntimeException e)
        {
            // if no
        }
        SharedPreferences sharedPreferences = context.getSharedPreferences(SHARED_PREF_NAME,
                                                                           Context.MODE_WORLD_WRITEABLE);
        // try to get from pref
        String deviceId = sharedPreferences.getString(SHARED_KEY, null);
        if (null != deviceId)
        {
            return deviceId;
        }
        // generate new
        deviceId = UUID.randomUUID().toString();
        SharedPreferences.Editor editor = sharedPreferences.edit();
        // and save it
        editor.putString(SHARED_KEY, deviceId);
        editor.commit();
        return deviceId;
    }

    static boolean isTablet(Context context)
    {
        // TODO: This hacky stuff goes away when we allow users to target devices
        int xlargeBit = 4; // Configuration.SCREENLAYOUT_SIZE_XLARGE;  // upgrade to HC SDK to get this
        Configuration config = context.getResources().getConfiguration();
        return (config.screenLayout & xlargeBit) == xlargeBit;
    }
}
