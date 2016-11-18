package com.example.nicolas.appsocialnetwork;

import android.os.AsyncTask;
import org.json.JSONException;
import org.json.JSONObject;
import java.io.BufferedInputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Map;

/**
 * Created by Nicolas on 15/11/2016.
 */

public class SendRequest extends AsyncTask<URL,String,JSONObject> {

    private URL ip;
    private JSONObject returnStringServer,jsonApp;
    private Integer idPost;
    private Boolean ok=true;
    private List<String> response = new ArrayList<>();
    private Map<String,List<String> > listInfoTopic = new HashMap<>();

    public SendRequest(final URL ipU, JSONObject jsonU, Integer idP){
        ip = ipU;
        jsonApp = jsonU;
        idPost = idP;
    }

    @Override
    protected JSONObject doInBackground(URL... urls) {

        try {
            String query = ip.toString();

            URL url = new URL(query);
            HttpURLConnection conn = (HttpURLConnection) url.openConnection();
            conn.setConnectTimeout(5000);
            conn.setRequestProperty("Content-Type", "application/json; charset=UTF-8");
            conn.setDoOutput(true);
            conn.setDoInput(true);
            conn.setRequestMethod("POST");

            OutputStream os = conn.getOutputStream();
            os.write(jsonApp.toString().getBytes("UTF-8"));
            os.close();

            // read the response
            InputStream in = new BufferedInputStream(conn.getInputStream());
            String result = org.apache.commons.io.IOUtils.toString(in, "UTF-8");

            returnStringServer = new JSONObject(result);

            if(Integer.valueOf(returnStringServer.getString("code"))!=200){
                ok=false;
            }

            setReturnServer();
            in.close();
            conn.disconnect();

            return returnStringServer;      /* server response */
        }
        catch( Exception e)
        {
            response.add(e.toString());
            ok=false;
            return null;
        }
    }

    public void setReturnServer(){
        response.clear();
        switch (idPost){
            //correspond au post authentification
            case 0:
                try {
                    response.add(returnStringServer.getString("code"));
                    Authentification.token =Integer.valueOf(returnStringServer.getString("message"));
                } catch (JSONException e) {
                    e.printStackTrace();
                }
                break;

            //correspond au post signUp
            case 1:
                //rien à récupérer
                break;

            //correspond au post poster topic
            case 2:
                //rien à récupérer
                break;

            //correspond au post topic alentour
            case 3:
                Integer i=0;
                Object val;

                if(ok==true){
                    for (Iterator iterator = returnStringServer.keys(); iterator.hasNext();) {

                        try{
                            Object cle = iterator.next();
                            if(i>0){
                                val = returnStringServer.get(String.valueOf(cle));
                                List<String> l = new ArrayList<>();
                                JSONObject values = new JSONObject(val.toString());
                                l.add(values.getString("topic"));
                                l.add(values.getString("popularity"));
                                l.add(values.getString("date"));
                                l.add(values.getString("hours"));
                                l.add(values.getString("latitude"));
                                l.add(values.getString("longitude"));
                                l.add(values.getString("id"));
                                /*response.add(values.getString("topic"));
                                response.add(values.getString("popularity"));
                                response.add(values.getString("date"));
                                response.add(values.getString("hours"));
                                response.add(values.getString("latitude"));
                                response.add(values.getString("longitude"));*/
                                listInfoTopic.put(cle.toString(),l);
                            }
                            i++;

                        }catch (JSONException e) {
                            e.printStackTrace();
                        }
                    }
                }else{
                    try {
                        response.add(returnStringServer.getString("code"));
                    } catch (JSONException e) {
                        e.printStackTrace();
                    }
                }

                break;

            //correspond au post deconnexion
            case 4:
                break;

            //correspond au post liker topic
            case 5:
                try {
                    response.add(returnStringServer.getString("code"));
                    response.add(returnStringServer.getString("popularity"));
                } catch (JSONException e) {
                    e.printStackTrace();
                }
                break;

            default:
                break;
        }

    }

    public Map<String,List<String> > getInfoTopic(){
        return listInfoTopic;
    }

    public boolean getConfirmResponse(){
        return ok;
    }

    public List<String> getResponse(){
        return response;
    }

}
