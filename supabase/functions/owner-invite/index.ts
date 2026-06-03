import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const html = `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>KafeProje owner invite</title>
  <style>
    :root {
      color-scheme: light dark;
      font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      background: #f7f4ef;
      color: #221b16;
    }
    body {
      margin: 0;
      min-height: 100vh;
      display: grid;
      place-items: center;
      padding: 24px;
    }
    main {
      width: min(520px, 100%);
      background: #ffffff;
      border: 1px solid #e5ddd3;
      border-radius: 18px;
      padding: 32px;
      box-shadow: 0 18px 48px rgba(70, 46, 23, 0.14);
    }
    h1 {
      margin: 0 0 12px;
      font-size: 28px;
      line-height: 1.15;
    }
    p {
      margin: 0 0 16px;
      color: #675c52;
      font-size: 16px;
      line-height: 1.55;
    }
    .status {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      margin-bottom: 18px;
      color: #8b4b15;
      font-weight: 700;
      font-size: 14px;
      text-transform: uppercase;
      letter-spacing: 0.04em;
    }
    .dot {
      width: 10px;
      height: 10px;
      border-radius: 50%;
      background: #bb641b;
    }
    @media (prefers-color-scheme: dark) {
      :root {
        background: #17130f;
        color: #fff8f0;
      }
      main {
        background: #211a15;
        border-color: #3a2e25;
      }
      p {
        color: #d4c4b5;
      }
      .status {
        color: #f0b26d;
      }
      .dot {
        background: #f0b26d;
      }
    }
  </style>
</head>
<body>
  <main>
    <div class="status"><span class="dot"></span> Invite accepted</div>
    <h1>You're ready to manage your cafe in KafeProje.</h1>
    <p>Your owner invite has been accepted. Open the KafeProje mobile app and sign in with the email address that received this invite.</p>
    <p>If you do not have a password yet, use the app's password reset flow for the same email address.</p>
  </main>
</body>
</html>`;

serve((req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "GET, OPTIONS",
      },
    });
  }

  if (req.method !== "GET") {
    return new Response("Method not allowed", { status: 405 });
  }

  return new Response(html, {
    headers: {
      "Content-Type": "text/html; charset=utf-8",
      "Cache-Control": "no-store",
    },
  });
});
