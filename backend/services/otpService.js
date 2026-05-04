const nodemailer = require("nodemailer");

// ── Build transporter from env ─────────────────────────────────────
// Supports: Mailtrap (dev), Gmail, SendGrid SMTP, Brevo, AWS SES
const buildTransporter = () => {
  // SendGrid SMTP (production default — most reliable for Pakistan)
  if (process.env.SMTP_HOST && process.env.SMTP_USER && process.env.SMTP_PASS) {
    return nodemailer.createTransport({
      host:   process.env.SMTP_HOST,
      port:   parseInt(process.env.SMTP_PORT || "587"),
      secure: process.env.SMTP_SECURE === "true",  // true for port 465
      auth: {
        user: process.env.SMTP_USER,
        pass: process.env.SMTP_PASS,
      },
      pool:           true,
      maxConnections: 5,
      rateDelta:      1000,
      rateLimit:      10,   // max 10 msgs/second
    });
  }
  // Gmail fallback (for local dev)
  if (process.env.GMAIL_USER && process.env.GMAIL_PASS) {
    return nodemailer.createTransport({
      service: "gmail",
      auth: { user: process.env.GMAIL_USER, pass: process.env.GMAIL_PASS },
    });
  }
  throw new Error("SMTP credentials not configured. Set SMTP_HOST/USER/PASS or GMAIL_USER/PASS in .env");
};

// ── Shared transporter instance (one connection pool) ─────────────
let _transporter = null;
const getTransporter = () => {
  if (!_transporter) _transporter = buildTransporter();
  return _transporter;
};

// ── HTML email template ───────────────────────────────────────────
const buildOtpHtml = (fullName, otp, role) => {
  const roleLabel  = role === "driver" ? "Driver Account" : "Rider Account";
  const digits     = otp.split("").map((d) =>
    `<td style="width:44px;height:54px;text-align:center;vertical-align:middle;background:#f0faf4;border:2px solid #00C853;border-radius:10px;font-size:26px;font-weight:900;color:#00C853;font-family:Arial,sans-serif">${d}</td>`
  ).join('<td style="width:8px"></td>');

  return `<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"/><meta name="viewport" content="width=device-width,initial-scale=1"/><title>EV Ride OTP</title></head>
<body style="margin:0;padding:0;background:#f4f6f9;font-family:Arial,Helvetica,sans-serif">
<table width="100%" cellpadding="0" cellspacing="0"><tr><td align="center" style="padding:40px 16px">
<table width="100%" style="max-width:520px;background:#ffffff;border-radius:20px;overflow:hidden;box-shadow:0 4px 24px rgba(0,0,0,0.08)" cellpadding="0" cellspacing="0">
  <tr><td style="background:linear-gradient(135deg,#00C853 0%,#00897B 100%);padding:32px 36px;text-align:center">
    <p style="margin:0;font-size:28px;font-weight:900;color:#fff;letter-spacing:-0.5px">⚡ EV Ride</p>
    <p style="margin:6px 0 0;font-size:13px;color:rgba(255,255,255,0.82)">Electric Rides, Smarter City</p>
  </td></tr>
  <tr><td style="padding:32px 36px">
    <span style="display:inline-block;background:#e8f5e9;color:#00897B;font-size:11px;font-weight:700;padding:4px 12px;border-radius:20px;text-transform:uppercase;letter-spacing:0.5px">${roleLabel}</span>
    <p style="font-size:16px;color:#0D1B2A;margin:18px 0 8px">Hi <strong>${fullName}</strong>,</p>
    <p style="font-size:13px;color:#6B7280;margin:0 0 22px;line-height:1.5">Use the verification code below to confirm your email. This code expires in <strong style="color:#EF4444">10 minutes</strong>.</p>
    <table cellpadding="0" cellspacing="0" style="margin:0 auto 24px"><tr>${digits}</tr></table>
    <p style="font-size:12px;color:#9CA3AF;text-align:center;margin:0">If you did not create this account, please ignore this email.</p>
  </td></tr>
  <tr><td style="padding:16px 36px 28px;border-top:1px solid #f0f0f0;text-align:center">
    <p style="margin:0;font-size:11px;color:#aaa">EV Ride &mdash; Karachi, Pakistan &nbsp;|&nbsp; <a href="#" style="color:#00C853;text-decoration:none">Support</a></p>
  </td></tr>
</table></td></tr></table></body></html>`;
};

// ── Send OTP email ─────────────────────────────────────────────────
const sendOtpEmail = async (toEmail, fullName, otp, role = "rider") => {
  const transporter = getTransporter();

  // Verify connection before first send (dev safety check)
  if (process.env.NODE_ENV !== "production") {
    await transporter.verify().catch((e) => {
      throw new Error(`SMTP connection failed: ${e.message}. Check your .env SMTP credentials.`);
    });
  }

  const info = await transporter.sendMail({
    from:    `"EV Ride ⚡" <${process.env.SMTP_FROM || process.env.SMTP_USER}>`,
    to:      toEmail,
    subject: `${otp} is your EV Ride verification code`,
    html:    buildOtpHtml(fullName, otp, role),
    text:    `Hi ${fullName},\n\nYour EV Ride verification code is: ${otp}\n\nThis code expires in 10 minutes.\n\nDo not share this code with anyone.\n\n— EV Ride Team`,
  });

  console.log(`[OTP EMAIL] Sent → ${toEmail} | MessageId: ${info.messageId}`);
  return info;
};

module.exports = { sendOtpEmail };
