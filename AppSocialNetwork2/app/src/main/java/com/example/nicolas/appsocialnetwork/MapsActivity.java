package com.example.nicolas.appsocialnetwork;

import android.content.Intent;
import android.location.Geocoder;
import android.location.LocationManager;
import android.support.v4.app.FragmentActivity;
import android.os.Bundle;
import android.view.View;
import android.widget.Button;
import com.google.android.gms.maps.CameraUpdateFactory;
import com.google.android.gms.maps.GoogleMap;
import com.google.android.gms.maps.OnMapReadyCallback;
import com.google.android.gms.maps.SupportMapFragment;
import com.google.android.gms.maps.model.BitmapDescriptorFactory;
import com.google.android.gms.maps.model.LatLng;
import com.google.android.gms.maps.model.MarkerOptions;
import java.io.IOException;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

public class MapsActivity extends FragmentActivity implements OnMapReadyCallback {

    private GoogleMap mMap;
    boolean enableMarker =false;
    Button btn;
    protected Map<String,List<String> > topicAvailable = new HashMap<>();



    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_maps);

        // Obtain the SupportMapFragment and get notified when the map is ready to be used.
        SupportMapFragment mapFragment = (SupportMapFragment) getSupportFragmentManager()
                .findFragmentById(R.id.map);
        mapFragment.getMapAsync(this);

        MainActivity.locationManager.requestLocationUpdates(LocationManager.GPS_PROVIDER, 0, 0, MainActivity.locationListener);

        Intent intent = getIntent();
        Bundle bd = intent.getExtras();
        if(bd!=null){
            enableMarker = bd.getBoolean("enableMarker");
            topicAvailable = (Map<String, List<String>>) bd.getSerializable("topic");
        }

        btn = (Button) findViewById(R.id.button3);

        if(enableMarker==false){
            btn.setText("Back");
        }else{
            btn.setText("Done");
        }
    }

    @Override
    public void onMapReady(GoogleMap googleMap) {
        mMap = googleMap;

        // Add a marker on the current position and move the camera
        LatLng point = new LatLng(MainActivity.latitude, MainActivity.longitude);
        mMap.addMarker(new MarkerOptions().position(point).title("Current position\n"+getCompleteAddress(MainActivity.latitude,MainActivity.longitude)));
        mMap.moveCamera(CameraUpdateFactory.newLatLngZoom(point,12));

        //Activite near me
        if(enableMarker==false){
            Button btnNearMy = (Button)findViewById(R.id.button3);
            setMarker();
            btnNearMy.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View v) {
                    finish();

                }
            });
        }else{
            Button btnNearMy = (Button)findViewById(R.id.button3);
            btnNearMy.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View v) {
                    setResult(10,null);
                    finish();

                }
            });
        }

        if(enableMarker==true){
            mMap.setOnMapLongClickListener(new GoogleMap.OnMapLongClickListener() {
                @Override
                public void onMapLongClick(LatLng latLng) {
                    mMap.clear();
                    LatLng point = new LatLng(latLng.latitude, latLng.longitude);
                    mMap.addMarker(new MarkerOptions().position(point).title(getCompleteAddress(latLng.latitude,latLng.longitude)));
                    MainActivity.latitude = latLng.latitude;
                    MainActivity.longitude = latLng.longitude;
                }
            });
        }
    }

    protected String getCompleteAddress(Double lat, Double lon){

        String completeAddress = new String(" ");
        Geocoder geocoder;
        List<android.location.Address> addresses;
        geocoder = new Geocoder(this, Locale.getDefault());

        /*try {
            addresses = geocoder.getFromLocation(lat, lon, 1); // Here 1 represent max location result to returned
            completeAddress = addresses.get(0).getAddressLine(0); // If any additional address line present than only, check with max available address lines by getMaxAddressLineIndex()
            String city = addresses.get(0).getLocality();
            completeAddress+="\n"+city;
            /*String state = addresses.get(0).getAdminArea();
            String country = addresses.get(0).getCountryName();
            String postalCode = addresses.get(0).getPostalCode();
            String knownName = addresses.get(0).getFeatureName();
        } catch (IOException e) {
            e.printStackTrace();
        }*/

        return completeAddress;
    }

    protected void setMarker(){

        Double d=0.0;
        for(Map.Entry<String, List<String> > entry : topicAvailable.entrySet()) {
            //String cle = entry.getKey();
            List<String> valeur = entry.getValue();
            d+=0.4;
            Double latitude = Double.valueOf(valeur.get(4));
            Double longitude = Double.valueOf(valeur.get(5));

            LatLng point = new LatLng(MainActivity.latitude+d, MainActivity.longitude+d);
            mMap.addMarker(new MarkerOptions().title(valeur.get(0)).position(point).icon(BitmapDescriptorFactory.defaultMarker(BitmapDescriptorFactory.HUE_GREEN))/*.title(getCompleteAddress(latitude,longitude))*/);
        }

    }
}
