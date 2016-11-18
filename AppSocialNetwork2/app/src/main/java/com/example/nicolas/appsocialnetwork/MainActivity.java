package com.example.nicolas.appsocialnetwork;

import android.Manifest;
import android.app.Activity;
import android.app.AlertDialog;
import android.content.Context;
import android.content.DialogInterface;
import android.content.SharedPreferences;
import android.graphics.Color;
import android.location.Location;
import android.location.LocationListener;
import android.location.LocationManager;
import android.os.AsyncTask;
import android.os.Bundle;
import android.support.v4.content.ContextCompat;
import android.view.Gravity;
import android.widget.Spinner;
import java.io.Serializable;
import java.net.MalformedURLException;
import java.net.URL;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ExecutionException;
import android.widget.ArrayAdapter;
import android.view.View;
import android.widget.AdapterView.OnItemSelectedListener;
import android.widget.AdapterView;
import android.widget.TableLayout;
import android.widget.TableRow;
import android.widget.TextView;
import android.widget.Toast;
import android.widget.Button;
import android.content.Intent;
import android.widget.SeekBar;
import android.support.v4.app.ActivityCompat;
import android.content.pm.PackageManager;
import android.provider.Settings;
import org.json.JSONException;
import org.json.JSONObject;

public class MainActivity extends Activity implements  OnItemSelectedListener {

    static boolean gps_enabled = false;
    private boolean network_enabled = false;
    static LocationManager locationManager;
    static double longitude=0;
    static double latitude=0;
    static LocationListener locationListener;
    protected TextView seekBarValue;
    protected String distance;
    protected SharedPreferences saveData;
    protected Spinner spinner;
    private URL urlWebService,urlWebServiceShare;
    private JSONObject jsonToSend;
    protected SendRequest sender=null;
    protected Map<String,List<String> > topicAvailable = new HashMap<>();
    protected TableLayout tableTopicAvailable;
    private Boolean permissionOk=false;
    SharedPreferences savData;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        tableTopicAvailable = (TableLayout) findViewById(R.id.tableTopicAvailable);

        jsonToSend = new JSONObject();
        try {
            urlWebService = new URL("https://appswg6.eu-gb.mybluemix.net/app/messages");
            urlWebServiceShare = new URL("https://appswg6.eu-gb.mybluemix.net/app/mess/key");
        } catch (MalformedURLException e) {
            e.printStackTrace();
        }

        spinner = (Spinner) findViewById(R.id.spinner);

        spinner.setOnItemSelectedListener(this);

        List<String> choixTemps = new ArrayList<String>();
        choixTemps.add("4 Hours");
        choixTemps.add("1 Day");
        choixTemps.add("3 Days");
        choixTemps.add("1 Week");

        ArrayAdapter<String> dataAdapter = new ArrayAdapter<String>(this,android.R.layout.simple_spinner_item,choixTemps);

        dataAdapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
        spinner.setAdapter(dataAdapter);

        //Activite near me
        Button btnNearMy = (Button)findViewById(R.id.button);
        btnNearMy.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                if(permissionOk){
                    getCurrentCoor();
                    if(gps_enabled==true) {
                        Intent intent = new Intent(MainActivity.this, MapsActivity.class);
                        intent.putExtra("enableMarker", false);
                        intent.putExtra("topic", (Serializable) topicAvailable);
                        startActivity(intent);
                    }
                }else{
                    checkPermissionGps();
                }
            }
        });

        Button btnMyPost =(Button)findViewById(R.id.button2);
        btnMyPost.setOnClickListener(new View.OnClickListener(){
            @Override
            public void onClick(View v){
                if(permissionOk){
                    getCurrentCoor();
                    Intent intent = new Intent(MainActivity.this,MyPostActivity.class);
                    startActivity(intent);
                }else{
                    checkPermissionGps();
                }
            }
        });

        //SEEKBAR
        saveData = getSharedPreferences(Authentification.PREFS_NAME,0);
        distance = saveData.getString("Distance","0");

        SeekBar seekBar = (SeekBar) findViewById(R.id.seekBar);
        seekBar.setProgress(Integer.parseInt(distance));
        seekBarValue = (TextView) findViewById(R.id.textView4);
        seekBarValue.setText(distance);

        seekBar.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener(){
            @Override
            public void onProgressChanged(SeekBar seekBar, int progress,
                                          boolean fromUser) {
                // TODO Auto-generated method stub
                seekBarValue.setText(String.valueOf(progress));
            }

            @Override
            public void onStartTrackingTouch(SeekBar seekBar) {
                // TODO Auto-generated method stub
            }

            @Override
            public void onStopTrackingTouch(SeekBar seekBar) {

                //topicAvailable.clear();

                for(int i=tableTopicAvailable.getChildCount();i>1;i--){
                    tableTopicAvailable.removeViewAt(i-1);
                }

                sendRequestServer(seekBar.getProgress());

                /*for(int i=0;i<10;i++){
                    List<String> l = new ArrayList<String>();
                    l.add("test"+Integer.toString(i));
                    l.add(Integer.toString(i));
                    l.add("0");
                    l.add("0");
                    l.add(Integer.toString(i+40));
                    l.add(Integer.toString(i+2));
                    topicAvailable.put(Integer.toString(i),l);
                }
                addRow();*/
            }

        });

        savData = getSharedPreferences(Authentification.PREFS_NAME,0);
        permissionOk = savData.getBoolean("permission",false);
    }

    protected void checkPermissionGps(){
        if ( ContextCompat.checkSelfPermission( this, Manifest.permission.ACCESS_COARSE_LOCATION ) != PackageManager.PERMISSION_GRANTED ) {

            ActivityCompat.requestPermissions( this, new String[] {  android.Manifest.permission.ACCESS_COARSE_LOCATION  },1);
        }
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, String permissions[], int[] grantResults) {
        switch (requestCode) {
            case 1: {
                // If request is cancelled, the result arrays are empty.
                if (grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                    permissionOk=true;
                    SharedPreferences.Editor editor = saveData.edit();
                    editor.putBoolean("permission",permissionOk);
                    editor.commit();
                    getCurrentCoor();
                } else {
                    permissionOk=false;
                }
                break;
            }
            default:
                permissionOk=false;
                break;
        }
    }

    protected  void getCurrentCoor(){

        locationListener = new MyLocationListener();
        locationManager = (LocationManager)this.getSystemService(Context.LOCATION_SERVICE);
        gps_enabled=locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER);
        network_enabled = locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER);

        if(gps_enabled==false){
            showAlertGps();
        }else{
            updateCoordinates();
        }
    }

    protected void sendRequestServer(Integer iProgress){

        try {
            jsonToSend.put("token",Integer.toString(Authentification.token));
            jsonToSend.put("latitude",Double.toString(MainActivity.latitude));
            jsonToSend.put("longitude",Double.toString(MainActivity.longitude));
            jsonToSend.put("radius",iProgress);
            jsonToSend.put("token",Authentification.token);

        } catch (JSONException e) {
            e.printStackTrace();
        }

        try {
            if(sender==null){
                sender = new SendRequest(urlWebService,jsonToSend,3);
            }

            sender.execute().get();

        } catch (InterruptedException e) {
            e.printStackTrace();
        } catch (ExecutionException e) {
            e.printStackTrace();
        }

        if(sender.getConfirmResponse()==true){
            setMapTopic();
            addRow();

        }else{
            List<String> s = sender.getResponse();
            String error = "Cannot get topics. An error occured: code "+s.get(0);
            Toast.makeText(getApplicationContext(),error,Toast.LENGTH_SHORT).show();
        }

        sender=null;

    }

    protected void setMapTopic(){

        topicAvailable.clear();
        topicAvailable = sender.getInfoTopic();

    }
    public void addRow(){

        for (String id: topicAvailable.keySet()) {
            TableRow row = new TableRow(this);
            row.setBackgroundColor(Color.BLACK);
            row.setLayoutParams(new TableRow.LayoutParams(TableRow.LayoutParams.MATCH_PARENT, TableRow.LayoutParams.MATCH_PARENT));

            TableRow.LayoutParams layoutParams = new TableRow.LayoutParams(TableRow.LayoutParams.MATCH_PARENT, TableRow.LayoutParams.MATCH_PARENT);
            layoutParams.setMargins(1,1,1,1);
            layoutParams.weight=1;

            Integer i =0;
            for(String info : topicAvailable.get(id)){
                if(i<3){
                    row.addView(generateTextView(info,layoutParams));
                }
                if(i==3){
                    row.addView(generateTextViewOption(layoutParams,id));
                }
                i++;
            }
            tableTopicAvailable.addView(row,layoutParams);
        }

    }

    protected TextView generateTextView(String texte, TableRow.LayoutParams ly) {

        TextView result = new TextView(this);
        result.setGravity(Gravity.CENTER);
        result.setText(texte);
        result.setBackgroundColor(Color.WHITE);
        result.setLayoutParams(ly);
        return result;
    }

    protected  TextView generateTextViewOption(TableRow.LayoutParams ly,final String id){

        final TextView result = new TextView(this);
        result.setOnClickListener(new View.OnClickListener(){
            @Override
            public void onClick(View v){
                final AlertDialog.Builder dialog = new AlertDialog.Builder(MainActivity.this);
                dialog.setTitle("Share topic")
                        .setMessage("Are you sure to share this topic?")
                        .setPositiveButton("Yes", new DialogInterface.OnClickListener(){
                            @Override
                            public void onClick(DialogInterface paramDialogInterface, int paramInt) {
                                SendRequest sender=null;

                                try {

                                    jsonToSend.put("key",topicAvailable.get(id).get(6));
                                    jsonToSend.put("token",Integer.toString(Authentification.token));
                                    sender = new SendRequest(urlWebServiceShare,jsonToSend,5);
                                    sender.execute().get();
                                } catch (InterruptedException e) {
                                    e.printStackTrace();
                                } catch (ExecutionException e) {
                                    e.printStackTrace();
                                } catch (JSONException e) {
                                    e.printStackTrace();
                                }

                                if(sender.getConfirmResponse()){
                                    List<String> response = sender.getResponse();
                                    List<String> listVal = topicAvailable.get(id);
                                    List<String> newList = new ArrayList<String>();
                                    Integer k=0;

                                    while (k<listVal.size())
                                    {
                                        if(k==1){
                                            newList.add(response.get(1));
                                        }else{
                                            newList.add(listVal.get(k));
                                        }
                                        k++;
                                    }
                                    topicAvailable.put(id,newList);

                                    if(tableTopicAvailable.getChildCount()>0){
                                        for(int i=tableTopicAvailable.getChildCount();i>1;i--){
                                            tableTopicAvailable.removeViewAt(i-1);
                                        }
                                    }
                                    addRow();
                                }else{
                                    Toast.makeText(getApplicationContext(),"An error occured while liking operation!",Toast.LENGTH_SHORT).show();
                                }

                            }
                        })
                        .setNegativeButton("No", new DialogInterface.OnClickListener() {
                            @Override
                            public void onClick(DialogInterface paramDialogInterface, int paramInt) {
                            }
                        });

                dialog.setCancelable(false);
                dialog.show();
            }

        });

        result.setGravity(Gravity.CENTER);
        result.setTag(id);
        result.setText("Like");
        result.setBackgroundColor(Color.WHITE);
        result.setLayoutParams(ly);
        return result;
    }

    private void showAlertGps() {

        final AlertDialog.Builder dialog = new AlertDialog.Builder(this);
        dialog.setTitle("Enable Location")
                .setMessage("Your Locations Settings is set to 'Off'.\nPlease Enable Location to " +
                        "use this app")
                .setPositiveButton("Location Settings", new DialogInterface.OnClickListener() {
                    @Override
                    public void onClick(DialogInterface paramDialogInterface, int paramInt) {
                        Intent myIntent = new Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS);
                        startActivityForResult(myIntent, 2);
                    }
                })
                .setNegativeButton("Cancel", new DialogInterface.OnClickListener() {
                    @Override
                    public void onClick(DialogInterface paramDialogInterface, int paramInt) {
                    }
                });
        dialog.setCancelable(false);
        dialog.show();
    }

    @Override
    public void onItemSelected(AdapterView<?> parent, View view, int position, long id) {
        // On selecting a spinner item
        String item = parent.getItemAtPosition(position).toString();

        // Showing selected spinner item
        Toast.makeText(parent.getContext(), "Selected: " + item, Toast.LENGTH_LONG).show();
    }

    public void onNothingSelected(AdapterView<?> arg0) {

    }

    private class MyLocationListener implements LocationListener {

        @Override
        public void onLocationChanged(Location location) {
                longitude = location.getLongitude();
                latitude = location.getLatitude();

        }

        @Override
        public void onStatusChanged(String provider, int status, Bundle extras) {

        }

        @Override
        public void onProviderEnabled(String provider) {

        }

        @Override
        public void onProviderDisabled(String provider) {

        }
    }

    @Override
    public void onBackPressed() {

        SharedPreferences.Editor editor = saveData.edit();
        editor.putString("Distance",seekBarValue.getText().toString());
        editor.putString("Time",spinner.getSelectedItem().toString());
        editor.commit();

        setResult(RESULT_CANCELED,null);
        finish();
    }

    public void updateCoordinates(){

        if (gps_enabled) {
            locationManager.requestLocationUpdates(LocationManager.GPS_PROVIDER, 0, 0, locationListener);
        }
        if (network_enabled) {
            locationManager.requestLocationUpdates(LocationManager.NETWORK_PROVIDER, 0, 0, locationListener);
        }
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        if(requestCode==2){
            if(resultCode==RESULT_CANCELED){
                gps_enabled=locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER);
                network_enabled = locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER);
                updateCoordinates();
            }
        }
    }
}
