package com.example.nicolas.appsocialnetwork;

import android.app.AlertDialog;
import android.content.Intent;
import android.graphics.Color;
import android.os.Bundle;
import android.provider.Settings;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.TableLayout;
import android.widget.TableRow;
import android.widget.TextView;
import android.widget.TableRow.LayoutParams;
import android.app.Activity;
import android.view.Gravity;
import java.net.MalformedURLException;
import java.net.URL;
import java.util.Calendar;
import java.text.SimpleDateFormat;
import java.util.List;
import java.util.concurrent.ExecutionException;

import android.content.DialogInterface;
import android.content.Context;
import android.view.inputmethod.InputMethodManager;
import android.location.LocationManager;
import android.widget.Toast;

import org.json.JSONException;
import org.json.JSONObject;

public class MyPostActivity extends Activity {

    TableLayout tableTopic;
    JSONObject jsonToSend;
    private URL urlWebServicePostTopic;
    protected SendRequest sender=null;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_my_post);
        final EditText textTopic = (EditText)findViewById(R.id.editText);

        jsonToSend = new JSONObject();
        try{
            urlWebServicePostTopic = new URL("https://appswg6.eu-gb.mybluemix.net/app/message");

        } catch (MalformedURLException e) {
            e.printStackTrace();
        }

        Button btnpost = (Button)findViewById(R.id.button5);

        btnpost.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                if(!textTopic.getText().toString().isEmpty()){

                    MainActivity.gps_enabled=MainActivity.locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER);
                    if(MainActivity.gps_enabled==true){
                        Intent intent = new Intent(MyPostActivity.this,MapsActivity.class);
                        intent.putExtra("enableMarker",true);
                        startActivityForResult(intent,1);
                    }else{
                        showAlertGps();
                    }

                }else{
                    AlertDialog alertDialog = new AlertDialog.Builder(MyPostActivity.this).create();
                    alertDialog.setTitle("Attention");
                    alertDialog.setMessage("You must set a name of topic.");
                    alertDialog.setButton(AlertDialog.BUTTON_NEUTRAL,"Ok",new DialogInterface.OnClickListener(){
                        public void onClick(DialogInterface dialog, int which){
                            dialog.dismiss();
                        }
                    });
                    alertDialog.setCancelable(false);
                    alertDialog.show();
                }
                InputMethodManager imm = (InputMethodManager) getSystemService(Context.INPUT_METHOD_SERVICE);
                imm.toggleSoftInput(InputMethodManager.SHOW_FORCED, 0);
            }
        });

        LinearLayout layoutMain = (LinearLayout) findViewById(R.id.mainLayout);
        layoutMain.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                textTopic.clearFocus();

            }
        });

    }

    public void addRow(){
        final EditText textTopic = (EditText)findViewById(R.id.editText);
        String d,h;

        tableTopic = (TableLayout) findViewById(R.id.tableMyTopic);

        TableRow row = new TableRow(this);
        row.setBackgroundColor(Color.BLACK);
        row.setLayoutParams(new LayoutParams(LayoutParams.MATCH_PARENT,LayoutParams.MATCH_PARENT));

        LayoutParams layoutParams = new LayoutParams(LayoutParams.MATCH_PARENT,LayoutParams.MATCH_PARENT);
        layoutParams.setMargins(1,1,1,1);
        layoutParams.weight=1;

        row.addView(generateTextView(textTopic.getText().toString(),layoutParams));
        row.addView(generateTextView(Integer.toString(0),layoutParams));

        Calendar c = Calendar.getInstance();

        d = getDate(c);
        h = getHeure(c);

        //send json data
        try {
            jsonToSend.put("topic",textTopic.getText().toString());
            jsonToSend.put("date",d);
            jsonToSend.put("hours",h);
            jsonToSend.put("latitude",MainActivity.latitude);
            jsonToSend.put("longitude",MainActivity.longitude);
            jsonToSend.put("token",Authentification.token);
        } catch (JSONException e) {
            e.printStackTrace();
        }

        sender = new SendRequest(urlWebServicePostTopic, jsonToSend,2);
        try {
            sender.execute().get();
        } catch (InterruptedException e) {
            e.printStackTrace();
        } catch (ExecutionException e) {
            e.printStackTrace();
        }

        if(sender.getConfirmResponse()==true){
            row.addView(generateTextView(d,layoutParams));

            tableTopic.addView(row,layoutParams);
        }else{
            List<String> s = sender.getResponse();
            String error = "Cannot send topics. An error occured: code "+s.get(0);
            Toast.makeText(getApplicationContext(),error,Toast.LENGTH_SHORT).show();
        }

        sender=null;
        textTopic.setText("");
        textTopic.clearFocus();
    }

    protected TextView generateTextView(String texte, LayoutParams ly) {
        TextView result = new TextView(this);
        result.setGravity(Gravity.CENTER);
        result.setText(texte);
        result.setBackgroundColor(Color.WHITE);
        result.setLayoutParams(ly);
        return result;
    }

    protected String getDate(Calendar c){

        SimpleDateFormat df = new SimpleDateFormat("dd-MMM-yyyy");
        return df.format(c.getTime());

    }

    protected String getHeure(Calendar c){

        SimpleDateFormat dh = new SimpleDateFormat("HH:mm:ss");
        return dh.format(c.getTime());

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
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        if(requestCode==1){
            if(resultCode!=RESULT_CANCELED){
                addRow();
            }
        }
        if(requestCode==2){
            if(resultCode==RESULT_CANCELED){

                Intent intent = new Intent(MyPostActivity.this,MapsActivity.class);
                intent.putExtra("enableMarker",true);
                startActivityForResult(intent,1);
            }
        }
    }

}
