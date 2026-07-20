{{--
    Touch Down Hosting — Terms of Service / Terms of Use.

    This page is edited EXTERNALLY only (same policy as the Dev-Blogs): update
    this file and redeploy. There is intentionally no in-panel editor for it.
--}}
<!DOCTYPE html>
<html lang="en">
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>{{ config('app.name', 'Touch Down Hosting') }} — Terms of Service</title>
        <link rel="icon" type="image/png" href="/favicons/favicon-32x32.png" sizes="32x32">
        <style>
            :root {
                --tdh-brand-400: #ff9633;
                --tdh-brand-500: #ff7a00;
                --tdh-brand-600: #e56700;
                --tdh-surface: rgba(18, 20, 24, 0.75);
                --tdh-border: rgba(255, 255, 255, 0.09);
                --tdh-text: #f5f7fa;
                --tdh-muted: #9aa3ad;
            }
            * { box-sizing: border-box; margin: 0; padding: 0; }
            body {
                font-family: 'IBM Plex Sans', 'Segoe UI', Roboto, system-ui, sans-serif;
                color: var(--tdh-text);
                background: #0c0d0f;
                background-image:
                    radial-gradient(1200px 800px at 85% -10%, rgba(255, 122, 0, 0.14), transparent 60%),
                    radial-gradient(1000px 700px at -10% 110%, rgba(255, 122, 0, 0.09), transparent 55%),
                    linear-gradient(160deg, #0a0b0d 0%, #101214 55%, #0d0b08 100%);
                background-attachment: fixed;
                line-height: 1.65;
                padding: 3rem 1rem;
            }
            .card {
                max-width: 860px;
                margin: 0 auto;
                background: var(--tdh-surface);
                border: 1px solid var(--tdh-border);
                border-top: 3px solid var(--tdh-brand-500);
                border-radius: 10px;
                backdrop-filter: blur(18px) saturate(155%);
                -webkit-backdrop-filter: blur(18px) saturate(155%);
                box-shadow: 0 12px 48px rgba(0, 0, 0, 0.5);
                padding: 2.5rem;
            }
            .logo { display: block; max-height: 72px; width: auto; margin: 0 auto 1.5rem; }
            h1 { font-size: 1.75rem; text-align: center; margin-bottom: 0.25rem; }
            .updated { text-align: center; color: var(--tdh-muted); font-size: 0.8rem; margin-bottom: 2rem; }
            h2 { font-size: 1.15rem; color: var(--tdh-brand-400); margin: 1.75rem 0 0.5rem; }
            p, li { color: var(--tdh-text); font-size: 0.95rem; margin-bottom: 0.75rem; }
            ul { padding-left: 1.5rem; margin-bottom: 0.75rem; }
            a { color: var(--tdh-brand-400); }
            .footer { text-align: center; color: var(--tdh-muted); font-size: 0.75rem; margin-top: 2.5rem; }
            .back {
                display: inline-block; margin-top: 1rem; padding: 0.6rem 1.5rem;
                background: linear-gradient(135deg, var(--tdh-brand-500), var(--tdh-brand-600));
                color: #fff; text-decoration: none; border-radius: 8px; font-weight: 600; font-size: 0.9rem;
            }
        </style>
    </head>
    <body>
        <div class="card">
            <img src="/logo.png" alt="Touch Down Hosting" class="logo" onerror="this.style.display='none'">
            <h1>Terms of Service &amp; Terms of Use</h1>
            <p class="updated">Touch Down Hosting Game Server Panel — last updated {{ config('touchdown.version') }}</p>

            <h2>1. Acceptance of Terms</h2>
            <p>
                By installing, configuring, accessing or using the Touch Down Hosting game server panel
                ("the Panel"), including creating or managing servers, nodes, or user accounts, you agree
                to be bound by these Terms of Service and Terms of Use. If you do not agree, do not use
                the Panel.
            </p>

            <h2>2. Early Development Software</h2>
            <p>
                The Panel is in an early (alpha) stage of development. You acknowledge that bugs, errors,
                outages, and occasional issues with servers, eggs, and panel features are expected and
                accepted as part of using early-stage software.
            </p>

            <h2>3. Limitation of Liability</h2>
            <p>
                To the maximum extent permitted by law, Touch Down Hosting and its developers, staff and
                contributors will <strong>not</strong> be liable for:
            </p>
            <ul>
                <li>any damages arising from use of, or inability to use, the Panel;</li>
                <li>loss of content, including server files, backups, databases or configurations;</li>
                <li>loss of profits, revenue or business opportunity;</li>
                <li>stolen, leaked or misused API keys, tokens or credentials;</li>
                <li>actions taken by third-party services integrated with the Panel (including payment gateways).</li>
            </ul>
            <p>You are responsible for maintaining your own backups and for keeping your credentials secure.</p>

            <h2>4. Acceptable Use</h2>
            <p>
                You agree not to use the Panel to host or distribute unlawful content, to attack or disrupt
                other systems, or to violate the terms of any game, platform or datacenter provider your
                servers run on. We may suspend or remove servers or accounts that violate these terms.
            </p>

            <h2>5. Your Data</h2>
            <p>
                The Panel stores account details, server configurations and activity records needed to
                operate the service. Payment gateway secrets are stored encrypted. We do not sell your data.
            </p>

            <h2>6. Support &amp; Bug Reports</h2>
            <p>
                Support is provided on a best-effort basis through our Discord community. For bug reports,
                open a ticket in the <strong>#forums</strong> channel and a member of our support staff will
                get back to you when available.
            </p>

            <h2>7. Changes to These Terms</h2>
            <p>
                These terms may be updated as the Panel matures. Continued use of the Panel after an update
                constitutes acceptance of the revised terms. Material changes will be announced in the
                panel's Dev-Blogs.
            </p>

            <div style="text-align:center">
                <a class="back" href="/">Back to the Panel</a>
            </div>

            <p class="footer">
                Touch Down Hosting &copy; {{ date('Y') }} &mdash; powered by Pterodactyl&reg;
            </p>
        </div>
    </body>
</html>
