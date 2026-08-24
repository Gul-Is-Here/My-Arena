/**
 * MyArena — Premium Email Template System
 *
 * Single reusable template with role-based theming.
 * Roles: "customer" | "owner" | "admin"
 *
 * Usage:
 *   const { buildEmail } = require("./emailTemplates");
 *   const html = buildEmail({ role, subject, headline, body, codeBlock, ctaButton, footerNote });
 */

// ── Role themes ──────────────────────────────────────────────────────────────

const THEMES = {
  customer: {
    accent:      "#CCFF00",   // Volt lime — customer brand
    accentDark:  "#A3CC00",
    accentLight: "#F5FFD6",
    portalLabel: "Customer Portal",
    portalIcon:  "⚡",
  },
  owner: {
    accent:      "#2979FF",   // Electric blue — owner brand
    accentDark:  "#1A5FD4",
    accentLight: "#EBF1FF",
    portalLabel: "Owner Portal",
    portalIcon:  "🏟️",
  },
  admin: {
    accent:      "#2979FF",   // Electric blue — admin authority
    accentDark:  "#1A5FD4",
    accentLight: "#EBF1FF",
    portalLabel: "Admin Portal",
    portalIcon:  "🛡️",
  },
};

// ── Logo SVG (inline, no external requests) ──────────────────────────────────

function logoSvg(accentColor) {
  return `
    <svg width="36" height="36" viewBox="0 0 36 36" fill="none" xmlns="http://www.w3.org/2000/svg" style="display:inline-block;vertical-align:middle;">
      <rect width="36" height="36" rx="10" fill="#0B0E11"/>
      <path d="M9 27L18 9L27 27" stroke="${accentColor}" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>
      <path d="M12 21H24" stroke="${accentColor}" stroke-width="2.5" stroke-linecap="round"/>
    </svg>`;
}

// ── OTP / Code block ─────────────────────────────────────────────────────────

function codeBlockHtml(code, label, expiry, accentColor, accentLight) {
  const digits = String(code).split("").map((d) => `
    <td style="padding:0 4px;">
      <div style="
        display:inline-block;
        width:44px;
        height:56px;
        line-height:56px;
        text-align:center;
        background:#FFFFFF;
        border:2px solid ${accentColor};
        border-radius:10px;
        font-size:28px;
        font-weight:800;
        color:#0B0E11;
        font-family:'SF Mono','Fira Code',monospace;
        letter-spacing:0;
      ">${d}</div>
    </td>`).join("");

  return `
    <table width="100%" cellpadding="0" cellspacing="0" border="0">
      <tr>
        <td align="center" style="padding:28px 0 8px;">
          <p style="margin:0 0 16px;font-size:13px;color:#6B7280;font-family:Arial,sans-serif;text-transform:uppercase;letter-spacing:1px;">
            ${label || "Your verification code"}
          </p>
          <table cellpadding="0" cellspacing="0" border="0" style="margin:0 auto;">
            <tr>${digits}</tr>
          </table>
          ${expiry ? `
          <p style="margin:14px 0 0;font-size:13px;color:#9CA3AF;font-family:Arial,sans-serif;">
            ⏱ Valid for ${expiry}
          </p>` : ""}
        </td>
      </tr>
    </table>`;
}

// ── CTA button ───────────────────────────────────────────────────────────────

function ctaButtonHtml(label, href, accentColor, textColor) {
  const tc = textColor || "#0B0E11";
  return `
    <table width="100%" cellpadding="0" cellspacing="0" border="0">
      <tr>
        <td align="center" style="padding:28px 0 12px;">
          <a href="${href}"
             style="
               display:inline-block;
               background:${accentColor};
               color:${tc};
               font-family:Arial,sans-serif;
               font-size:16px;
               font-weight:700;
               text-decoration:none;
               padding:14px 40px;
               border-radius:12px;
               letter-spacing:0.3px;
             ">${label}</a>
        </td>
      </tr>
    </table>`;
}

// ── Divider ──────────────────────────────────────────────────────────────────

const divider = `
  <table width="100%" cellpadding="0" cellspacing="0" border="0">
    <tr><td style="border-top:1px solid #F3F4F6;padding:0;font-size:0;">&nbsp;</td></tr>
  </table>`;

// ── Main template builder ─────────────────────────────────────────────────────

/**
 * @param {object} opts
 * @param {"customer"|"owner"|"admin"} opts.role
 * @param {string}  opts.headline        — Large heading inside the card
 * @param {string}  opts.bodyHtml        — Body paragraphs (safe HTML)
 * @param {object}  [opts.code]          — { value, label, expiry }
 * @param {object}  [opts.cta]           — { label, href }
 * @param {string}  [opts.footerNote]    — Small print below the main card
 * @param {string}  [opts.securityNote]  — "If you didn't request this…" line
 */
function buildEmail(opts) {
  const {
    role = "customer",
    headline,
    bodyHtml,
    code,
    cta,
    footerNote,
    securityNote,
  } = opts;

  const theme = THEMES[role] || THEMES.customer;
  const { accent, accentDark, accentLight, portalLabel, portalIcon } = theme;

  // Customer emails use lime-on-dark header (lime needs dark bg to pop);
  // Owner/admin use white header with blue/indigo accent chip.
  const isCustomer = role === "customer";
  const headerBg   = isCustomer ? "#0B0E11" : "#FFFFFF";
  const headerText = isCustomer ? accent     : "#0B0E11";

  const codeSection  = code ? codeBlockHtml(code.value, code.label, code.expiry, accent, accentLight) : "";
  // Lime (#CCFF00) needs dark text; blue (#2979FF) needs white text
  const ctaBtnTextColor = isCustomer ? "#0B0E11" : "#FFFFFF";
  const ctaSection   = cta  ? ctaButtonHtml(cta.label, cta.href, accent, ctaBtnTextColor) : "";

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8"/>
  <meta name="viewport" content="width=device-width,initial-scale=1"/>
  <meta name="color-scheme" content="light"/>
  <meta name="x-apple-disable-message-reformatting"/>
  <title>MyArena</title>
  <!--[if mso]>
  <noscript><xml><o:OfficeDocumentSettings><o:PixelsPerInch>96</o:PixelsPerInch></o:OfficeDocumentSettings></xml></noscript>
  <![endif]-->
</head>
<body style="margin:0;padding:0;background:#F9FAFB;-webkit-text-size-adjust:100%;-ms-text-size-adjust:100%;">

<!-- ── Preheader (hidden preview text) ── -->
<div style="display:none;max-height:0;overflow:hidden;mso-hide:all;">
  ${headline} — MyArena ${portalLabel}
  &nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;
</div>

<!-- ── Outer wrapper ── -->
<table width="100%" cellpadding="0" cellspacing="0" border="0" style="background:#F9FAFB;">
  <tr>
    <td align="center" style="padding:40px 16px;">

      <!-- ── Email card ── -->
      <table width="100%" cellpadding="0" cellspacing="0" border="0"
             style="max-width:560px;background:#FFFFFF;border-radius:20px;overflow:hidden;
                    box-shadow:0 4px 24px rgba(0,0,0,0.08);">

        <!-- ── Header ── -->
        <tr>
          <td style="background:${headerBg};padding:28px 40px;">
            <table width="100%" cellpadding="0" cellspacing="0" border="0">
              <tr>
                <td style="vertical-align:middle;">
                  ${logoSvg(accent)}
                  <span style="
                    display:inline-block;
                    vertical-align:middle;
                    margin-left:10px;
                    font-family:Arial,sans-serif;
                    font-size:20px;
                    font-weight:800;
                    color:${headerText};
                    letter-spacing:-0.5px;
                  ">MyArena</span>
                </td>
                <td align="right" style="vertical-align:middle;">
                  <span style="
                    display:inline-block;
                    background:${isCustomer ? "#1E252C" : accentLight};
                    color:${isCustomer ? accent : accentDark};
                    font-family:Arial,sans-serif;
                    font-size:11px;
                    font-weight:700;
                    padding:5px 12px;
                    border-radius:99px;
                    letter-spacing:0.5px;
                    text-transform:uppercase;
                  ">${portalIcon} ${portalLabel}</span>
                </td>
              </tr>
            </table>
          </td>
        </tr>

        <!-- ── Accent bar ── -->
        <tr>
          <td style="background:${accent};height:3px;font-size:0;line-height:0;">&nbsp;</td>
        </tr>

        <!-- ── Body ── -->
        <tr>
          <td style="padding:40px 40px 32px;">

            <!-- Headline -->
            <h1 style="
              margin:0 0 16px;
              font-family:Arial,sans-serif;
              font-size:26px;
              font-weight:800;
              color:#0B0E11;
              letter-spacing:-0.5px;
              line-height:1.2;
            ">${headline}</h1>

            <!-- Body text -->
            <div style="font-family:Arial,sans-serif;font-size:15px;line-height:1.65;color:#374151;">
              ${bodyHtml}
            </div>

            <!-- OTP code block -->
            ${codeSection}

            <!-- CTA button -->
            ${ctaSection}

            ${(codeSection || ctaSection) && securityNote ? divider : ""}

            <!-- Security note -->
            ${securityNote ? `
            <p style="
              margin:20px 0 0;
              font-family:Arial,sans-serif;
              font-size:13px;
              color:#9CA3AF;
              line-height:1.6;
            ">${securityNote}</p>` : ""}

          </td>
        </tr>

        <!-- ── Footer note (optional extra content above footer) ── -->
        ${footerNote ? `
        <tr>
          <td style="padding:0 40px 28px;">
            <div style="
              background:#F9FAFB;
              border:1px solid #F3F4F6;
              border-radius:12px;
              padding:16px 20px;
              font-family:Arial,sans-serif;
              font-size:13px;
              color:#6B7280;
              line-height:1.6;
            ">${footerNote}</div>
          </td>
        </tr>` : ""}

        <!-- ── Footer ── -->
        <tr>
          <td style="background:#F9FAFB;border-top:1px solid #F3F4F6;padding:24px 40px;">
            <table width="100%" cellpadding="0" cellspacing="0" border="0">
              <tr>
                <td>
                  <p style="margin:0;font-family:Arial,sans-serif;font-size:12px;color:#9CA3AF;">
                    © ${new Date().getFullYear()} MyArena. All rights reserved.
                  </p>
                  <p style="margin:4px 0 0;font-family:Arial,sans-serif;font-size:12px;color:#9CA3AF;">
                    Questions? Contact us at
                    <a href="mailto:support@myarena.app" style="color:${accent};text-decoration:none;">support@myarena.app</a>
                  </p>
                </td>
                <td align="right" style="vertical-align:top;">
                  <span style="font-family:Arial,sans-serif;font-size:11px;color:#D1D5DB;">
                    ${portalIcon}
                  </span>
                </td>
              </tr>
            </table>
          </td>
        </tr>

      </table>
      <!-- /email card -->

    </td>
  </tr>
</table>

</body>
</html>`;
}

module.exports = { buildEmail, THEMES };
