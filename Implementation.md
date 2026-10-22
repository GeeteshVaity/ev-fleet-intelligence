Add the example code to your application
1
Configure your user pool app client with allowed callback URLs, logout URLs, and the scopes that you want to request, for example openid and profile. Learn more 

2
Install the AppAuth-Android  library.


implementation 'net.openid:appauth:<version>'
3
Configure Amazon Cognito as your authorization service. To implement authorization code grants , your application must be able to discover issuer endpoints from the .well-known/openid-configuration endpoint for your user pool issuer. Create an AuthorizationServiceConfiguration instance with the URL of your user pool discovery document. Note: Code samples in Java


AuthorizationServiceConfiguration cognitoServiceConfig =
    AuthorizationServiceConfiguration.fetchFromIssuer(
    Uri.parse("https://cognito-idp.ap-south-1.amazonaws.com/ap-south-1_5Kd0M6Ks1"),
    new AuthorizationServiceConfiguration.RetrieveConfigurationCallback() {
        public void onFetchConfigurationCompleted(
            @Nullable AuthorizationServiceConfiguration cognitoServiceConfig,
            @Nullable AuthorizationException ex) {
            if (ex != null) {
                // failed to fetch Cognito service config;
                return;
            }
            // use retrieved cognitoServiceConfig as needed, such as
            // AuthState authState = new AuthState(cognitoServiceConfig);
    }
});
4
Configure your application to direct users to your user pool authorization endpoint and obtain an authorization code. Construct an AuthorizationRequest from your cognitoServiceConfig and your app client ID.


AuthorizationRequest.Builder authRequestBuilder = new AuthorizationRequest.Builder(
    cognitoServiceConfig,    // Cognito service config retrieved from the Discovery document
    "cu99248mdofvm2p56lccnit0h",    // Cognito app client ID
    ResponseTypeValues.CODE,    // CODE for response_type
    "https://d84l1y8p4kdic.cloudfront.net")    // redirect_uri that receives auth responses from Cognito
    .setScope("email openid phone");    // OAuth scopes

// Note: Your app’s redirect URI must be added to your Cognito app client Allowed callback URLs.
5
Dispatch the AuthorizationRequest with startActivityForResult.


private void doAuthorization() {
    AuthorizationService authService = new AuthorizationService(this);
    Intent authIntent = authService.getAuthorizationRequestIntent(authRequest);
    startActivityForResult(authIntent, INIT_AUTH);
}

@Override
protected void onActivityResult(int requestCode, int resultCode, Intent data) {
    if (requestCode == INIT_AUTH) {
        AuthorizationResponse resp = AuthorizationResponse.fromIntent(data);
        AuthorizationException ex = AuthorizationException.fromIntent(data);
        // ... process the result
    } else {
        // ...
    }
}
6
Capture the authorization redirect. After a user signs in with managed login, Amazon Cognito redirects them to the return URL. Configure a handler at the return URL for Android. Use a manifest placeholder for a custom URL scheme. If your return URL has an HTTPS URL schema, you can add an intent filter for RedirectUriReceiverActivity in AndroidManifest.xml.


android.defaultConfig.manifestPlaceholders = [
  'appAuthRedirectScheme': 'cognito.sample.android.demo'
]
7
Get the authorization response from the fromIntent() methods AuthorizationResponse or AuthorizationException.


public void onStart() {
    AuthorizationResponse response = AuthorizationResponse.fromIntent(getIntent());
    AuthorizationException ex = AuthorizationException.fromIntent(getIntent());
    if (response != null) {
        // authorization succeeded
    } else {
        // authorization failed
    }
}
8
Configure a handler for the AuthorizationResponse to exchange the authorization code for user pool tokens. Assemble a token-exchange request with createTokenExchangeRequest and implement TokenResponseCallback(). A successful exchange produces a TokenResponse object.


authService.performTokenRequest(
    authorizationResponse.createTokenExchangeRequest(),
    new AuthorizationService.TokenResponseCallback() {
        @Override
        public void onTokenRequestCompleted(TokenResponse response, AuthorizationException ex) {
            // use the response, such as authState.update(response, ex);
            if (response != null) {
                // exchange succeeded
            } else {
                // exchange failed
            }
        }
    });
9
Configure session-end behavior for users who sign out. Assemble an EndSessionRequest to your user pool logout endpoint .


EndSessionRequest endSessionRequest =
    new EndSessionRequest.Builder(cognitoServiceConfiguration)
        .setIdTokenHint(ID_TOKEN) // retrieve the ID_TOKEN from the TokenResponse
        .setPostLogoutRedirectUri("<logout uri>")
        .setAdditionalParameters(Map.of(
             "client_id", "cu99248mdofvm2p56lccnit0h",
             "logout_uri", "<logout uri>"))
        .build();
// Note: Your app’s end-session redirect URI must be added to your Cognito app client Allowed sign out URLs.
10
Dispatch the EndSessionRequest with startActivityForResult.


private void endSession() {
    AuthorizationService authService = new AuthorizationService(this);
    Intent endSessionIntent = authService.getEndSessionRequestIntent(endSessionRequest);
    startActivityForResult(endSessionIntent, END_SESSION);
}

@Override
protected void onActivityResult(int requestCode, int resultCode, Intent data) {
    if (requestCode == END_SESSION) {
        EndSessionResponse resp = EndSessionResponse.fromIntent(data);
        AuthorizationException ex = AuthorizationException.fromIntent(data);
        // ... process the result
    } else {
        // ...
    }
}