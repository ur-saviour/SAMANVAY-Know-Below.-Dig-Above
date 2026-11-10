import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { Webhook } from "https://esm.sh/standardwebhooks@1.0.0";

type AuthHookEvent = {
  user?: { id?: string; phone?: string };
  sms?: { otp?: string };
};

type TwilioResult = {
  ok: boolean;
  status: number;
  code?: string;
};

const json = (body: Record<string, unknown>, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
    },
  });

const requiredEnv = (name: string): string => {
  const value = Deno.env.get(name)?.trim();
  if (!value) throw new Error(`Missing server secret: ${name}`);
  return value;
};

const twilioPost = async (
  accountSid: string,
  authToken: string,
  fields: Record<string, string>,
): Promise<TwilioResult> => {
  const body = new URLSearchParams(fields);
  const credentials = btoa(`${accountSid}:${authToken}`);
  const response = await fetch(
    `https://api.twilio.com/2010-04-01/Accounts/${accountSid}/Messages.json`,
    {
      method: "POST",
      headers: {
        "Authorization": `Basic ${credentials}`,
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body,
    },
  );

  let payload: Record<string, unknown> = {};
  try {
    payload = await response.json();
  } catch {
    payload = {};
  }

  return {
    ok: response.ok,
    status: response.status,
    code: payload.code == null ? undefined : String(payload.code),
  };
};

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return json({ error: "Method not allowed." }, 405);
  }

  try {
    // The hook secret is generated in Supabase Authentication > Hooks.
    // Verify the signed event before reading or relaying the one-time code.
    const hookSecret = requiredEnv("SEND_SMS_HOOK_SECRET");
    const signingSecret = hookSecret.replace(/^v1,whsec_/, "");
    const payload = await req.text();
    const headers = Object.fromEntries(req.headers.entries());
    const event = new Webhook(signingSecret).verify(
      payload,
      headers,
    ) as AuthHookEvent;

    const phone = event.user?.phone ?? "";
    const otp = event.sms?.otp ?? "";
    if (!/^\+[1-9]\d{7,14}$/.test(phone)) {
      return json({ error: "Auth event did not contain a valid E.164 phone number." }, 400);
    }
    if (!/^\d{6}$/.test(otp)) {
      return json({ error: "Auth event did not contain a valid six-digit OTP." }, 400);
    }

    const accountSid = requiredEnv("TWILIO_ACCOUNT_SID");
    const authToken = requiredEnv("TWILIO_AUTH_TOKEN");
    const whatsappFromRaw = requiredEnv("TWILIO_WHATSAPP_FROM");
    const whatsappFrom = whatsappFromRaw.startsWith("whatsapp:")
      ? whatsappFromRaw
      : `whatsapp:${whatsappFromRaw}`;
    const whatsappContentSid = requiredEnv("TWILIO_WHATSAPP_CONTENT_SID");

    const smsMessagingServiceSid = Deno.env.get(
      "TWILIO_SMS_MESSAGING_SERVICE_SID",
    )?.trim();
    const smsFrom = Deno.env.get("TWILIO_SMS_FROM")?.trim();
    if (!smsMessagingServiceSid && !smsFrom) {
      throw new Error(
        "Set TWILIO_SMS_MESSAGING_SERVICE_SID or TWILIO_SMS_FROM.",
      );
    }

    const smsFields: Record<string, string> = {
      To: phone,
      Body: `Your SAMANVAY verification code is ${otp}. Do not share this code with anyone.`,
    };
    if (smsMessagingServiceSid) {
      smsFields.MessagingServiceSid = smsMessagingServiceSid;
    } else {
      smsFields.From = smsFrom!;
    }

    // Optional India domestic DLT identifiers. For domestic India SMS,
    // configure these to match the registered entity and approved OTP template.
    const dltEntityId = Deno.env.get("TWILIO_SMS_DLT_ENTITY_ID")?.trim();
    const dltTemplateId = Deno.env.get("TWILIO_SMS_DLT_TEMPLATE_ID")?.trim();
    if (Boolean(dltEntityId) !== Boolean(dltTemplateId)) {
      throw new Error(
        "Set both TWILIO_SMS_DLT_ENTITY_ID and TWILIO_SMS_DLT_TEMPLATE_ID, or neither.",
      );
    }
    if (dltEntityId && dltTemplateId) {
      smsFields.DltEntityId = dltEntityId;
      smsFields.DltTemplateId = dltTemplateId;
    }

    // WhatsApp Authentication templates are pre-approved in Twilio.
    // Variable 1 must be the OTP slot in the approved Content Template.
    const whatsappFields: Record<string, string> = {
      To: `whatsapp:${phone}`,
      From: whatsappFrom,
      ContentSid: whatsappContentSid,
      ContentVariables: JSON.stringify({ "1": otp }),
    };

    // Submit both channels using the SAME OTP issued by Supabase Auth.
    const [smsResult, whatsappResult] = await Promise.all([
      twilioPost(accountSid, authToken, smsFields),
      twilioPost(accountSid, authToken, whatsappFields),
    ]);

    if (!smsResult.ok || !whatsappResult.ok) {
      // Do not log or return the OTP or recipient phone number.
      console.error("Dual-channel OTP delivery did not complete.", {
        smsStatus: smsResult.status,
        smsCode: smsResult.code,
        whatsappStatus: whatsappResult.status,
        whatsappCode: whatsappResult.code,
      });
      return json({
        error: "OTP delivery failed on one or more required channels.",
        channels: {
          sms: smsResult.ok ? "accepted" : "failed",
          whatsapp: whatsappResult.ok ? "accepted" : "failed",
        },
      }, 502);
    }

    // Auth considers the hook successful only after both providers accept it.
    return json({
      delivered: true,
      channels: { sms: "accepted", whatsapp: "accepted" },
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown hook error";
    // Never log request bodies, OTPs, phone numbers, or provider credentials.
    console.error("Dual-channel OTP hook failed.", { message });
    return json({ error: "Dual-channel OTP delivery is not configured or could not be completed." }, 503);
  }
});
