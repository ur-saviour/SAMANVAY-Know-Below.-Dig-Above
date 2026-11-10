# SAMANVAY OTP sign-in setup

SAMANVAY supports passwordless sign-in with a registered email address or a verified mobile number. The login request uses Supabase Auth with account creation disabled, so an unknown email address or phone number is not silently converted into a new account.

## 1. Email OTP

In the Supabase Dashboard for project `zhtotivedvkmclerdnlf`:

1. Open **Authentication → Email Templates**.
2. Open the **Magic Link** template.
3. Make it display the one-time token. Example:

```html
<h2>SAMANVAY sign-in code</h2>
<p>Enter this six-digit code in the SAMANVAY app:</p>
<h1>{{ .Token }}</h1>
<p>If you did not request this code, ignore this email.</p>
```

4. Save the template and confirm the project has a working SMTP sender.

Supabase uses the Magic Link template for email OTP. The `{{ .Token }}` variable is the six-digit code the app verifies.

## 2. Mobile OTP to SMS and WhatsApp

The app asks Supabase Auth to generate **one** OTP. The deployed Send SMS Auth Hook relays that same OTP to both SMS and WhatsApp. It does not generate a second code.

### Deployed endpoint

```text
https://zhtotivedvkmclerdnlf.supabase.co/functions/v1/samanvay-dual-channel-otp
```

The Edge Function is deployed and active. It verifies Supabase's Standard Webhooks signature before using the OTP. It never logs or stores the code or recipient number. It returns success to Supabase Auth only when both providers accept the message request.

### Configure the Supabase Auth Hook

In the Supabase Dashboard:

1. Open **Authentication → Hooks**.
2. Create a **Send SMS Hook** and choose the HTTP endpoint option.
3. Set the endpoint URL to the deployed URL shown above.
4. Generate the hook secret and save the hook.
5. Copy the full generated value (format starts with `v1,whsec_`) into the Edge Function secret named `SEND_SMS_HOOK_SECRET`. Do not put it in Flutter, GitHub source, or this document.

The Edge Function's JWT verification is disabled because Supabase Auth calls it before a user session exists. The function instead verifies the signed Standard Webhooks request.

### Configure provider secrets

Configure these in the Supabase project's **Edge Functions → Secrets** area. Do not add these values to the mobile app.

| Secret | Required value |
|---|---|
| `SEND_SMS_HOOK_SECRET` | The full secret generated when creating the Supabase Send SMS Hook |
| `TWILIO_ACCOUNT_SID` | Twilio Account SID |
| `TWILIO_AUTH_TOKEN` | Twilio Auth Token |
| `TWILIO_SMS_FROM` | An approved SMS sender, when not using a Messaging Service |
| `TWILIO_SMS_MESSAGING_SERVICE_SID` | Optional alternative to `TWILIO_SMS_FROM` |
| `TWILIO_WHATSAPP_FROM` | Approved WhatsApp sender, in `whatsapp:+countrycode...` format |
| `TWILIO_WHATSAPP_CONTENT_SID` | SID of an approved WhatsApp **Authentication** content template (normally begins `HX`) |
| `TWILIO_SMS_DLT_ENTITY_ID` | Optional India domestic SMS DLT entity ID; set together with the template ID |
| `TWILIO_SMS_DLT_TEMPLATE_ID` | Optional India domestic SMS DLT template ID; set together with the entity ID |

The function sends:
- SMS with the OTP in the body, through the configured Twilio sender or Messaging Service.
- WhatsApp using the approved WhatsApp Authentication template and its OTP variable `1`.

The WhatsApp template must be approved by WhatsApp. It must be an Authentication template that supports the OTP variable; an ordinary free-form WhatsApp message template is not interchangeable.

### India SMS registration

For India domestic SMS, the sender and message template need the applicable DLT registration/approval and provider-side setup. Use an approved template whose wording matches the SMS body sent by the function:

```text
Your SAMANVAY verification code is {#var#}. Do not share this code with anyone.
```

If the authorised SMS provider has a different approved template, update the SMS body in the Edge Function to match that exact approved wording before enabling the hook. Follow the provider's instructions for Entity ID, Template ID, Sender ID and any required telemarketer chain. Do not use unregistered or unapproved sender/template details.

### Important activation check

The hook is **not active for sign-in until** the Dashboard hook is saved and all required Edge Function secrets and approved sender/template details are configured. Until then, mobile OTP may fail or only follow whatever SMS delivery configuration is active on the project. Do not present it as dual-channel live until a real test confirms both channels accepted the same OTP.

External SMS/WhatsApp providers may charge per message or require an approved business sender. Provider account, billing and regulatory registration should be handled by the authorised platform owner.

## 3. Link existing accounts to mobile numbers

The current SAMANVAY Auth data was checked earlier: six email-confirmed accounts and no verified phone numbers. Existing users should first sign in using **Email OTP**.

After email sign-in:

1. Open **My Profile**.
2. Select **Link mobile number**.
3. Enter the mobile number and request verification.
4. Enter the code. The same OTP should arrive through SMS and WhatsApp after dual-channel hook setup is active.
5. Once Supabase confirms the phone number, sign out and test **Mobile OTP** from the login screen.

The phone-link page updates the currently authenticated Supabase user. It does not create a new Auth account or modify the user's SAMANVAY role/profile row. Indian 10-digit numbers are formatted as `+91XXXXXXXXXX`; international numbers must include their country calling code.

## 4. Operational safeguards

- Login OTP requests use `shouldCreateUser: false`.
- Supabase Auth generates and verifies the OTP; the app does not store the code.
- The Auth Hook verifies its signed request before relaying the OTP.
- The UI enforces a 60-second resend wait. Supabase Auth also enforces server-side rate limits.
- The hook requires both SMS and WhatsApp provider requests to succeed before it returns success to Supabase Auth.
- Do not use the local read-only officer demo IDs as live account credentials. Existing numeric staff aliases resolve to their original email accounts.
- Enable CAPTCHA/rate-limit protections and monitor Auth/Edge Function logs before public rollout.

## 5. Verification checklist

- [ ] Email template displays `{{ .Token }}` and sends a six-digit code.
- [ ] Email OTP login succeeds for a confirmed existing account.
- [ ] Supabase Send SMS Hook is saved with the deployed endpoint and its matching secret.
- [ ] All required Twilio and DLT secrets are configured without exposing them to the Flutter client.
- [ ] Twilio has an approved SMS sender/template for the intended India route.
- [ ] Twilio/WhatsApp has an approved Authentication template with the OTP variable.
- [ ] A real test number receives the same OTP through SMS and WhatsApp.
- [ ] The OTP from either channel creates the same authenticated Supabase session.
- [ ] An email-authenticated user can link and verify a mobile number in My Profile.
- [ ] Citizen, department, coordinator and administrator accounts open their correct role-gated workspace after OTP verification.
- [ ] An unknown email/phone address does not create a new user through the login screen.

## Reference documentation

- Supabase [Send SMS Auth Hook](https://supabase.com/docs/guides/auth/auth-hooks/send-sms-hook)
- Supabase [Auth Hooks](https://supabase.com/docs/guides/auth/auth-hooks)
- Twilio [WhatsApp Authentication templates](https://www.twilio.com/docs/content/whatsappauthentication)
- Twilio [India SMS guidelines](https://www.twilio.com/en-us/guidelines/in/sms)
