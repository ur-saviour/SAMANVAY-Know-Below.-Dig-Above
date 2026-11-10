# SAMANVAY OTP sign-in setup

The app now supports passwordless sign-in with either a registered email address or a verified mobile number. Both methods authenticate the existing Supabase Auth user; the login screen sends OTP requests with `shouldCreateUser: false`, so it does not create duplicate accounts.

## 1. Enable email OTP delivery

In the Supabase Dashboard for project `zhtotivedvkmclerdnlf`:

1. Open **Authentication → Email Templates**.
2. Open the **Magic Link** template.
3. Change the template so it displays the OTP token, not a confirmation URL. For example:

```html
<h2>SAMANVAY sign-in code</h2>
<p>Enter this six-digit code in the SAMANVAY app:</p>
<h1>{{ .Token }}</h1>
<p>If you did not request this code, you can ignore this email.</p>
```

4. Save the template and ensure the project has a working SMTP sender configured.

Supabase's email OTP and magic-link flows use the same template. The `{{ .Token }}` variable is required for the app's six-digit code entry screen.

## 2. Enable mobile OTP delivery

In the Supabase Dashboard:

1. Open **Authentication → Sign-in / Providers → Phone**.
2. Enable phone sign-in.
3. Configure a supported SMS provider and its credentials in the provider settings.
4. Use a message template that includes Supabase's `{{ .Code }}` variable, for example: `Your SAMANVAY verification code is {{ .Code }}`.
5. Save and test the provider using a phone number that you control.

The app formats 10-digit Indian mobile numbers as `+91XXXXXXXXXX`. International numbers must include their country calling code. Production SMS delivery in India must use a provider and message-template setup that meets applicable telecom/DLT requirements.

## 3. Link existing accounts to mobile numbers

The current SAMANVAY Auth data contains six email-confirmed accounts and no verified phone numbers. Therefore, those users must first sign in using **Email OTP**.

After email sign-in:

1. Open **My Profile**.
2. Select **Link mobile number**.
3. Enter the mobile number and request the verification code.
4. Enter the code received on that number.
5. Return to the sign-in screen and use **Mobile OTP** for future sign-ins.

The mobile-link page updates the currently authenticated Supabase user. It does not create a new Auth account or modify the user's SAMANVAY role/profile row.

## 4. Operational safeguards

- The login flow does not create users when requesting an OTP.
- The six-digit OTP is verified by Supabase Auth; the app never stores the code.
- The UI enforces a 60-second resend wait, and Supabase applies its own rate limits.
- Do not use the local read-only officer demonstration IDs as live account credentials. The legacy numeric staff aliases resolve to their existing email addresses for OTP delivery.
- Enable CAPTCHA/rate-limit protections before public production rollout and monitor failed OTP sends with Supabase Auth logs.

## 5. Verification checklist

- [ ] Email template displays `{{ .Token }}` and sends a six-digit code.
- [ ] Email OTP login succeeds for a confirmed existing account.
- [ ] Phone sign-in is enabled and an SMS provider successfully delivers `{{ .Code }}`.
- [ ] An email-authenticated user can link and verify a mobile number in My Profile.
- [ ] That same account can then sign in with the verified phone OTP.
- [ ] Citizen, department, coordinator and administrator profiles still open the correct role-gated workspace after OTP verification.
- [ ] Unknown email/phone addresses do not create new users through the login screen.
