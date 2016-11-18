package com.example.nicolas.appsocialnetwork;

import android.app.AlertDialog;
import android.app.Dialog;
import android.content.Context;
import android.content.DialogInterface;
import android.content.SharedPreferences;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.PorterDuff;
import android.graphics.Typeface;
import android.support.v7.app.AppCompatActivity;
import android.os.Bundle;
import android.content.Intent;
import android.text.InputType;
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

public class Authentification extends AppCompatActivity {

    Button btnLogin;
    EditText editUser, editPassword;
    TextView tx1,textCreatAccount,textForgotPass;
    int counter = 3;
    JSONObject jsonToSend;
    private URL urlWebService;
    public static final String PREFS_NAME = "SaveDataApp";
    SharedPreferences savData;
    protected SendRequest sender=null;
    static Integer token =-10;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_authentification);

        jsonToSend = new JSONObject();
        try{
            urlWebService = new URL("https://authswg6.eu-gb.mybluemix.net/connect");

        } catch (MalformedURLException e) {
            e.printStackTrace();
        }

        btnLogin = (Button)findViewById(R.id.button);
        editUser = (EditText)findViewById(R.id.editText);
        editPassword = (EditText)findViewById(R.id.editText2);

        editUser.requestFocus();
        InputMethodManager imm = (InputMethodManager) getSystemService(Context.INPUT_METHOD_SERVICE);
        imm.showSoftInput(editUser, InputMethodManager.SHOW_IMPLICIT);

        editUser.getBackground().setColorFilter(Color.rgb(103,200,187),PorterDuff.Mode.SRC_IN);
        editPassword.getBackground().setColorFilter(Color.rgb(103,200,187),PorterDuff.Mode.SRC_IN);

        tx1 = (TextView)findViewById(R.id.textView3);
        tx1.setVisibility(View.GONE);

        btnLogin.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {

                View view = getCurrentFocus();
                if (view != null) {
                    InputMethodManager imm = (InputMethodManager)getSystemService(Context.INPUT_METHOD_SERVICE);
                    imm.hideSoftInputFromWindow(view.getWindowToken(), 0);
                }

                    Boolean bVerif =true;

                    //si le champs utilisateur est vide
                    if(editUser.getText().toString().isEmpty()==true){
                        editUser.setError("User name is requiered");
                        bVerif =false;
                    }

                    //si le champs password est vide
                    if(editPassword.getText().toString().isEmpty()==true){
                        editPassword.setError("Password is requiered");
                        bVerif=false;
                    }

                    //si ok
                    if(bVerif==true){
                        try {
                            jsonToSend.put("user",editUser.getText().toString());
                            jsonToSend.put("password",editPassword.getText().toString());
                        } catch (JSONException e) {
                            e.printStackTrace();
                        }

                        try {
                            if(sender==null){
                                sender = new SendRequest(urlWebService,jsonToSend,0);
                            }
                            sender.execute().get();

                        } catch (InterruptedException e) {
                            e.printStackTrace();
                        } catch (ExecutionException e) {
                            e.printStackTrace();
                        }

                        //si l'utilisateur est identifier on peut continuer sinon message raison
                        if(sender.getConfirmResponse()==true){

                            Intent topicAc = new Intent(Authentification.this,MainActivity.class);
                            startActivityForResult(topicAc,1);

                            SharedPreferences.Editor editor = savData.edit();
                            editor.putString("User",editUser.getText().toString());
                            editor.putString("Password",editPassword.getText().toString());

                            editor.commit();

                        }else{
                            List<String> s = sender.getResponse();
                            String error = "An error occured: code "+s.get(0);
                            Toast.makeText(getApplicationContext(),error,Toast.LENGTH_SHORT).show();

                            tx1.setVisibility(View.VISIBLE);
                            tx1.setBackgroundColor(Color.RED);
                            counter--;
                            tx1.setText(Integer.toString(counter));

                            if (counter == 0) {
                                btnLogin.setEnabled(false);
                            }
                        }

                        sender=null;
                    }
            }
        });

        savData = getSharedPreferences(Authentification.PREFS_NAME,0);
        editUser.setText(savData.getString("User",""));
        editPassword.setText(savData.getString("Password",""));

        textCreatAccount = (TextView) findViewById(R.id.textView7);
        textCreatAccount.setPaintFlags(textCreatAccount.getPaintFlags() | Paint.UNDERLINE_TEXT_FLAG);
        textCreatAccount.setOnClickListener(new View.OnClickListener(){
            @Override
            public void onClick(View v){
                Intent activitySignUp = new Intent(Authentification.this,SingUp.class);
                startActivity(activitySignUp);
            }
        });

        textForgotPass = (TextView) findViewById(R.id.textView8);
        textForgotPass.setPaintFlags(textForgotPass.getPaintFlags() | Paint.UNDERLINE_TEXT_FLAG);
        textForgotPass.setOnClickListener(new View.OnClickListener(){
            @Override
            public void onClick(View v){

                AlertDialog.Builder builder = new AlertDialog.Builder(Authentification.this);
                EditText editEmail = new EditText(builder.getContext());
                editEmail.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_VARIATION_NORMAL);
                editEmail.setHint("User");
                editEmail.setTypeface(null, Typeface.ITALIC);

                Dialog dialog = builder.create();
                dialog.getWindow().setNavigationBarColor(Color.RED);
                builder.setMessage("Please, enter your user name:")
                        .setTitle("Forgot your password")
                        .setView(editEmail)
                        .setPositiveButton("Ok", new DialogInterface.OnClickListener() {
                            public void onClick(DialogInterface dialog, int id) {
                                // FIRE ZE MISSILES!
                            }
                        })
                        .setNegativeButton("Cancel", new DialogInterface.OnClickListener() {
                            public void onClick(DialogInterface dialog, int id) {
                                // User cancelled the dialog
                            }
                        });

                builder.setCancelable(false);
                builder.show();
            }
        });
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        if(requestCode==1){
            if(resultCode==RESULT_CANCELED){
                finish();
            }
        }
    }

}
