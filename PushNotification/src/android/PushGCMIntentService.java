//
//  MessageActivity.java
//
// Pushwoosh Push Notifications SDK
// www.pushwoosh.com
//
// MIT Licensed

package com.arellomobile.android.push;

import android.app.ActivityManager;
import android.app.Notification;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.media.AudioManager;
import android.media.MediaPlayer;
import android.media.Ringtone;
import android.media.RingtoneManager;
import android.net.Uri;
import android.os.Bundle;
import android.os.Vibrator;
import android.util.Log;
import android.widget.Toast;
import com.google.android.gcm.GCMBaseIntentService;

import java.util.List;

public class PushGCMIntentService extends GCMBaseIntentService
{
    @SuppressWarnings("hiding")
    private static final String TAG = "GCMIntentService";
    private static boolean mSimpleNotification = true;

    public PushGCMIntentService()
    {
        String senderId = PushManager.mSenderId;
        Boolean simpleNotification = PushManager.sSimpleNotification;
        if (null != simpleNotification)
        {
            mSimpleNotification = simpleNotification;
        }
        if (null == senderId)
        {
            senderId = "";
        }
        mSenderId = senderId;
    }

    @Override
    protected void onRegistered(Context context, String registrationId)
    {
        Log.i(TAG, "Device registered: regId = " + registrationId);
        DeviceRegistrar.registerWithServer(context, registrationId);
    }

    @Override
    protected void onUnregistered(Context context, String registrationId)
    {
        Log.i(TAG, "Device unregistered");
        DeviceRegistrar.unregisterWithServer(context, registrationId);
    }

    @Override
    protected void onMessage(Context context, Intent intent)
    {
        Log.i(TAG, "Received message");
        // notifies user
        generateNotification(context, intent);
    }

    @Override
    protected void onDeletedMessages(Context context, int total)
    {
        Log.i(TAG, "Received deleted messages notification");

        // TODO
        Toast.makeText(context, "onDeletedMessages", Toast.LENGTH_SHORT).show();
    }

    @Override
    public void onError(Context context, String errorId)
    {
        Log.e(TAG, "Messaging registration error: " + errorId);
        PushEventsTransmitter.onRegisterError(context, errorId);
    }

    @Override
    protected boolean onRecoverableError(Context context, String errorId)
    {
        // log message
        Log.i(TAG, "Received recoverable error: " + errorId);
        return super.onRecoverableError(context, errorId);
    }

    private static void generateNotification(Context context, Intent intent)
    {
        Bundle extras = intent.getExtras();
        if (extras == null)
        {
            return;
        }

        extras.putBoolean("foregroud", isAppOnForeground(context));

        String title = (String) extras.get("title");
        String url = (String) extras.get("h");
        String link = (String) extras.get("l");

        // empty message with no data
        Intent notifyIntent = null;
        if (link != null)
        {
            // we want main app class to be launched
            notifyIntent = new Intent(Intent.ACTION_VIEW, Uri.parse(link));
            notifyIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        }
        else
        {
            notifyIntent = new Intent(context, PushHandlerActivity.class);
            notifyIntent.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP | Intent.FLAG_ACTIVITY_CLEAR_TOP);

            // pass all bundle
            notifyIntent.putExtra("pushBundle", extras);
        }

        NotificationManager manager = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);

        // first string will appear on the status bar once when message is added
        CharSequence appName = context.getPackageManager().getApplicationLabel(context.getApplicationInfo());
        if (null == appName)
        {
            appName = "";
        }

        String newMessageString = ": new message";
        int resId = context.getResources().getIdentifier("new_push_message", "string", context.getPackageName());
        if (0 != resId)
        {
            newMessageString = context.getString(resId);
        }
        Notification notification = new Notification(context.getApplicationInfo().icon, appName + newMessageString,
                                                     System.currentTimeMillis());

        // remove the notification from the status bar after it is selected
        notification.flags |= Notification.FLAG_AUTO_CANCEL;

        if (mSimpleNotification)
        {
            createSimpleNotification(context, notifyIntent, notification, appName, title, manager);
        }
        else
        {
            createMultyNotification(context, notifyIntent, notification, appName, title, manager);
        }


        String sound = (String) extras.get("s");
        AudioManager am = (AudioManager) context.getSystemService(Context.AUDIO_SERVICE);
        if (PushManager.sSoundType == SoundType.ALWAYS || (am
                .getRingerMode() == AudioManager.RINGER_MODE_NORMAL && PushManager.sSoundType == SoundType.DEFAULT_MODE))
        {
            // if always or normal type set
            playPushNotificationSound(context, sound);
        }
        if (PushManager.sVibrateType == VibrateType.ALWAYS || (am
                .getRingerMode() == AudioManager.RINGER_MODE_VIBRATE && PushManager.sVibrateType == VibrateType.DEFAULT_MODE))
        {
            makeVibrate(context);
        }
    }

    private static void makeVibrate(Context context)
    {
        try
        {
            Vibrator v = (Vibrator) context.getSystemService(Context.VIBRATOR_SERVICE);
            // Start immediately
            // Vibrate for 200 milliseconds
            // Sleep for 500 milliseconds
            long[] pattern = {0, 300, 200, 300, 200};

            v.vibrate(pattern, -1);
        } catch (Exception e)
        {
            e.printStackTrace();
        }
    }

    private static void createSimpleNotification(Context context, Intent notifyIntent, Notification notification,
                                                 CharSequence appName, String title, NotificationManager manager)
    {
        PendingIntent contentIntent = PendingIntent.getActivity(context, 0, notifyIntent,
                                                                PendingIntent.FLAG_CANCEL_CURRENT);

        // this will appear in the notifications list
        notification.setLatestEventInfo(context, appName, title, contentIntent);
        manager.notify(PushManager.MESSAGE_ID, notification);
    }

    private static void createMultyNotification(Context context, Intent notifyIntent, Notification notification,
                                                CharSequence appName, String title, NotificationManager manager)
    {
        PendingIntent contentIntent = PendingIntent
                .getActivity(context, PushManager.MESSAGE_ID, notifyIntent, PendingIntent.FLAG_UPDATE_CURRENT);

        // this will appear in the notifications list
        notification.setLatestEventInfo(context, appName, title, contentIntent);
        manager.notify(PushManager.MESSAGE_ID++, notification);
    }

    private static void playPushNotificationSound(Context context, String sound)
    {
        MediaPlayer mediaPlayer = null;
        if (sound == null)
        {
            // try to get default one
            try
            {
                Uri notification = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION);
                Ringtone r = RingtoneManager.getRingtone(context.getApplicationContext(), notification);
                if (null != r)
                {
                    r.setStreamType(AudioManager.STREAM_NOTIFICATION);
                    r.play();
                }
            } catch (Exception e)
            {
                // A Uri that will point to the current default ringtone at any given time.
                // If the current default ringtone is in the DRM provider
                // and the caller does not have permission, the exception will be a FileNotFoundException
                // (see javadoc for Settings.System.DEFAULT_RINGTONE_URI)
            }
        }
        else
        {
            int soundId = context.getResources().getIdentifier(sound, "raw", context.getPackageName());
            if (0 != soundId)
            {
                // if found valid resource id
                mediaPlayer = MediaPlayer.create(context, soundId);
            }
        }

        playPushNotificationSound(mediaPlayer);
    }

    private static void playPushNotificationSound(MediaPlayer mediaPlayer)
    {
        if (null != mediaPlayer)
        {
            // if player created
            mediaPlayer.setAudioStreamType(AudioManager.STREAM_MUSIC);
            mediaPlayer.setLooping(false);
            mediaPlayer.setOnCompletionListener(new MediaPlayer.OnCompletionListener()
            {
                @Override
                public void onCompletion(MediaPlayer mediaPlayer)
                {
                    mediaPlayer.stop();
                    mediaPlayer.release();
                }
            });
            mediaPlayer.setOnSeekCompleteListener(new MediaPlayer.OnSeekCompleteListener()
            {
                @Override
                public void onSeekComplete(MediaPlayer mediaPlayer)
                {
                    mediaPlayer.stop();
                    mediaPlayer.release();
                }
            });
            mediaPlayer.start();
        }
    }

    private static boolean isAppOnForeground(Context context)
    {
        ActivityManager activityManager = (ActivityManager) context.getSystemService(Context.ACTIVITY_SERVICE);
        List<ActivityManager.RunningAppProcessInfo> appProcesses = activityManager.getRunningAppProcesses();
        if (appProcesses == null)
        {
            return false;
        }

        final String packageName = context.getPackageName();
        for (ActivityManager.RunningAppProcessInfo appProcess : appProcesses)
        {
            if (appProcess.importance == ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND && appProcess
                    .processName.equals(packageName))
            {
                return true;
            }
        }

        return false;
    }

}

