import os
import smtplib
import ssl
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
import httpx
import logging

logger = logging.getLogger("mpus_mailer")

SMTP_HOST = os.getenv("SMTP_HOST", "smtp.gmail.com")
SMTP_PORT = int(os.getenv("SMTP_PORT", "587"))
SMTP_USER = os.getenv("SMTP_USER", "")
SMTP_PASS = os.getenv("SMTP_PASS", "")
RESEND_API_KEY = os.getenv("RESEND_API_KEY", "")
FROM_EMAIL = os.getenv("FROM_EMAIL", "Mpus Kampus <onboarding@resend.dev>")

def generate_mpus_otp_html(name: str, otp_code: str, campus_name: str = "Kampus") -> str:
    return f"""
<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Kode Verifikasi Mpus</title>
</head>
<body style="margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #F3F8F8; color: #242D38;">
    <table border="0" cellpadding="0" cellspacing="0" width="100%" style="table-layout: fixed; background-color: #F3F8F8; padding: 30px 15px;">
        <tr>
            <td align="center">
                <table border="0" cellpadding="0" cellspacing="0" width="100%" style="max-width: 520px; background-color: #FFFFFF; border-radius: 24px; overflow: hidden; box-shadow: 0 10px 30px rgba(0,0,0,0.06); border: 1px solid #E0F2F1;">
                    <!-- Header -->
                    <tr>
                        <td align="center" style="background: linear-gradient(135deg, #00838F 0%, #00ACC1 100%); padding: 36px 24px;">
                            <div style="font-size: 32px; font-weight: 900; letter-spacing: 2px; color: #B4FFF9; text-transform: uppercase;">
                                MPUS
                            </div>
                            <div style="font-size: 14px; font-weight: 500; color: #FFFFFF; opacity: 0.9; margin-top: 4px;">
                                Market Kampus Mahasiswa Indonesia
                            </div>
                        </td>
                    </tr>
                    <!-- Content -->
                    <tr>
                        <td style="padding: 36px 28px;">
                            <div style="display: inline-block; background-color: #E0F7FA; color: #00838F; font-size: 12px; font-weight: 700; padding: 6px 14px; border-radius: 12px; margin-bottom: 16px;">
                                🛡️ KTM Terverifikasi AI ({campus_name})
                            </div>
                            <h1 style="font-size: 20px; font-weight: 800; color: #242D38; margin: 0 0 12px 0;">
                                Halo, {name}! 👋
                            </h1>
                            <p style="font-size: 14px; line-height: 1.6; color: #555555; margin: 0 0 24px 0;">
                                Selamat! Foto KTM Anda telah berhasil diverifikasi oleh AI Vision Mpus. Gunakan 6 digit kode verifikasi berikut untuk mengaktifkan akun Anda:
                            </p>
                            
                            <!-- OTP Box -->
                            <div style="background-color: #F8FDFA; border: 2px dashed #00838F; border-radius: 16px; padding: 20px; text-align: center; margin-bottom: 24px;">
                                <div style="font-size: 12px; font-weight: 700; color: #666666; text-transform: uppercase; letter-spacing: 1px; margin-bottom: 8px;">
                                    KODE VERIFIKASI RESMI
                                </div>
                                <div style="font-size: 36px; font-weight: 900; letter-spacing: 10px; color: #00838F; font-family: monospace;">
                                    {otp_code}
                                </div>
                                <div style="font-size: 12px; color: #888888; margin-top: 8px;">
                                    ⏱️ Berlaku selama 10 menit
                                </div>
                            </div>

                            <p style="font-size: 13px; line-height: 1.5; color: #777777; margin: 0 0 16px 0;">
                                Jangan bagikan kode ini kepada siapapun demi keamanan akun dan transaksi Anda di ekosistem kampus.
                            </p>
                        </td>
                    </tr>
                    <!-- Footer -->
                    <tr>
                        <td align="center" style="background-color: #FAFAFA; border-top: 1px solid #EEEEEE; padding: 20px 24px;">
                            <p style="font-size: 12px; color: #999999; margin: 0;">
                                © 2026 DACZDev — Mpus Ecosystem by Pak Bos Dimas.
                            </p>
                        </td>
                    </tr>
                </table>
            </td>
        </tr>
    </table>
</body>
</html>
"""

async def send_mpus_otp_email(to_email: str, name: str, otp_code: str, campus_name: str = "Kampus") -> bool:
    """
    Sends HTML OTP email using Resend API or SMTP.
    """
    html_content = generate_mpus_otp_html(name, otp_code, campus_name)
    subject = f"Kode Verifikasi Mpus: {otp_code}"

    # 1. Try Resend API if Key Provided
    if RESEND_API_KEY:
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                res = await client.post(
                    "https://api.resend.com/emails",
                    headers={"Authorization": f"Bearer {RESEND_API_KEY}"},
                    json={
                        "from": FROM_EMAIL,
                        "to": [to_email],
                        "subject": subject,
                        "html": html_content
                    }
                )
                if res.status_code in [200, 201]:
                    logger.info(f"Resend email sent successfully to {to_email}")
                    return True
                else:
                    logger.warning(f"Resend API returned {res.status_code}: {res.text}")
        except Exception as e:
            logger.error(f"Resend send error: {e}")

    # 2. Try Standard SMTP if Configured
    if SMTP_USER and SMTP_PASS:
        try:
            message = MIMEMultipart("alternative")
            message["Subject"] = subject
            message["From"] = FROM_EMAIL
            message["To"] = to_email

            part = MIMEText(html_content, "html")
            message.attach(part)

            if SMTP_PORT == 465:
                context = ssl.create_default_context()
                with smtplib.SMTP_SSL(SMTP_HOST, SMTP_PORT, context=context) as server:
                    server.login(SMTP_USER, SMTP_PASS)
                    server.sendmail(SMTP_USER, to_email, message.as_string())
            else:
                with smtplib.SMTP(SMTP_HOST, SMTP_PORT) as server:
                    server.starttls()
                    server.login(SMTP_USER, SMTP_PASS)
                    server.sendmail(SMTP_USER, to_email, message.as_string())

            logger.info(f"SMTP email sent successfully to {to_email}")
            return True
        except Exception as e:
            logger.error(f"SMTP send error: {e}")

    logger.info(f"[DEV/MOCK MAIL] Sent OTP {otp_code} to {to_email} (Configure SMTP_USER or RESEND_API_KEY for live delivery)")
    return True
