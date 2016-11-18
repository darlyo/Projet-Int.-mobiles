package com.example.nicolas.appsocialnetwork;

import android.content.Context;
import android.graphics.Paint;
import android.support.v7.app.AppCompatActivity;
import android.os.Bundle;
import android.view.View;
import android.view.inputmethod.InputMethodManager;
import android.widget.Button;
import android.widget.EditText;
import android.widget.TextView;
import android.widget.Toast;

import org.json.JSONException;
import org.json.JSONObject;

import java.net.MalformedURLException;
import java.net.URL;
import java.util.List;
import java.util.concurrent.ExecutionException;

public class SingUp extends AppCompatActivity {

    protected TextView textAuth;
    protected Button btnCreatAccount;
    protected EditText etEmail,etUser,etPassword;
    private URL urlWebService;
    private JSONObject jsonToSend;
    protected SendRequest sender=null;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_sing_up);

        jsonToSend = new JSONObject();

        try{
            urlWebService = new URL("https://authswg6.eu-gb.mybluemix.net/signup");

        } catch (MalformedURLException e) {
            e.printStackTrace();
        }

        etEmail = (EditText)findViewById(R.id.editText3);
        etUser = (EditText)findViewById(R.id.editText4);
        etPassword = (EditText)findViewById(R.id.editText5);

        etEmail.requestFocus();
        InputMethodManager imm = (InputMethodManager) getSystemService(Context.INPUT_METHOD_SERVICE);
        imm.showSoftInput(etEmail, InputMethodManager.SHOW_IMPLICIT);

        textAuth = (TextView) findViewById(R.id.textView5);
        textAuth.setPaintFlags(textAuth.getPaintFlags() | Paint.UNDERLINE_TEXT_FLAG);
        textAuth.setOnClickListener(new View.OnClickListener(){
            @Override
            public void onClick(View v){
                finish();
            }
        });

        btnCreatAccount = (Button)findViewById(R.id.button4);
        btnCreatAccount.setOnClickListener(new View.OnClickListener(){
            @Override
            public void onClick(View v){

                Boolean bVerif=true;
                if(etUser.getText().toString().isEmpty()){
                    etUser.setError("User name is requiered");
                    bVerif=false;
                }
                if(etPassword.getText().toString().isEmpty()){
                    etPassword.setError("Password is requiered");
                    bVerif=false;
                }
                if(etEmail.getText().toString().isEmpty()){
                    etEmail.setError("Email is requiered");
                    bVerif=false;
                }

                if(bVerif==true){
                    try {
                        jsonToSend.put("user",etUser.getText().toString());
                        jsonToSend.put("password",etPassword.getText().toString());
                        jsonToSend.put("email",etEmail.getText().toString());
                    } catch (JSONException e) {
                        e.printStackTrace();
                    }

                    try {
                        if(sender==null){
                            sender = new SendRequest(urlWebService,jsonToSend,1);
                        }

                        sender.execute().get();

                    } catch (InterruptedException e) {
                        e.printStackTrace();
                    } catch (ExecutionException e) {
                        e.printStackTrace();
                    }

                    if(sender.getConfirmResponse()==true){
                        Toast.makeText(getApplicationContext(),"Your account was successfully created.",Toast.LENGTH_SHORT).show();
                        finish();
                    }else{
                        List<String> s = sender.getResponse();
                        String error = "An error occured: code "+s.get(0);
                        Toast.makeText(getApplicationContext(),error,Toast.LENGTH_SHORT).show();
                    }

                    sender=null;
                }

            }
        });
    }



}
