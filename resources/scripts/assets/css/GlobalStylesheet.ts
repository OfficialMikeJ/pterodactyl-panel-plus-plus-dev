import tw from 'twin.macro';
import { createGlobalStyle } from 'styled-components/macro';
// @ts-expect-error untyped font file
import font from '@fontsource-variable/ibm-plex-sans/files/ibm-plex-sans-latin-wght-normal.woff2';

export default createGlobalStyle`
    @font-face {
        font-family: 'IBM Plex Sans';
        font-style: normal;
        font-display: swap;
        font-weight: 100 700;
        src: url(${font}) format('woff2-variations');
        unicode-range: U+0000-00FF,U+0131,U+0152-0153,U+02BB-02BC,U+02C6,U+02DA,U+02DC,U+0304,U+0308,U+0329,U+2000-206F,U+20AC,U+2122,U+2191,U+2193,U+2212,U+2215,U+FEFF,U+FFFD;
    }

    /*
     * Touch Down Hosting theme variables. These defaults are the "Cool Orange"
     * theme — JSON themes loaded at runtime override these values on :root.
     */
    :root {
        --tdh-brand-50: #fff5eb;
        --tdh-brand-100: #ffe8d1;
        --tdh-brand-200: #ffd0a3;
        --tdh-brand-300: #ffb266;
        --tdh-brand-400: #ff9633;
        --tdh-brand-500: #ff7a00;
        --tdh-brand-600: #e56700;
        --tdh-brand-700: #c65500;
        --tdh-brand-800: #9a4200;
        --tdh-brand-900: #7a3300;
        --tdh-bg: radial-gradient(1200px 800px at 85% -10%, rgba(255, 122, 0, 0.14), transparent 60%),
            radial-gradient(1000px 700px at -10% 110%, rgba(255, 122, 0, 0.09), transparent 55%),
            linear-gradient(160deg, #0a0b0d 0%, #101214 55%, #0d0b08 100%);
        --tdh-bg-solid: #0c0d0f;
        --tdh-surface: rgba(18, 20, 24, 0.6);
        --tdh-surface-strong: rgba(13, 15, 18, 0.82);
        --tdh-surface-border: rgba(255, 255, 255, 0.09);
        --tdh-glow: rgba(255, 122, 0, 0.3);
        --tdh-text: #f5f7fa;
        --tdh-text-muted: #9aa3ad;
    }

    body {
        ${tw`font-sans`};
        background: var(--tdh-bg-solid);
        background-image: var(--tdh-bg);
        background-attachment: fixed;
        background-size: cover;
        color: var(--tdh-text);
        letter-spacing: 0.015em;
    }

    h1, h2, h3, h4, h5, h6 {
        ${tw`font-medium tracking-normal font-header`};
    }

    p {
        ${tw`leading-snug font-sans`};
        color: var(--tdh-text);
    }

    form {
        ${tw`m-0`};
    }

    textarea, select, input, button, button:focus, button:focus-visible {
        ${tw`outline-none`};
    }

    input[type=number]::-webkit-outer-spin-button,
    input[type=number]::-webkit-inner-spin-button {
        -webkit-appearance: none !important;
        margin: 0;
    }

    input[type=number] {
        -moz-appearance: textfield !important;
    }

    ::selection {
        background: var(--tdh-brand-500);
        color: #fff;
    }

    /*
     * Google's invisible reCAPTCHA parks a floating badge over the bottom-right
     * of the viewport, which collides with the login card and the trophy toasts.
     * Hiding it is permitted as long as the reCAPTCHA branding appears in the
     * user flow — the attribution line under the login form provides that.
     */
    .grecaptcha-badge {
        visibility: hidden !important;
    }

    /* Reusable Touch Down Hosting glass morphism surface. */
    .tdh-glass {
        background: var(--tdh-surface);
        border: 1px solid var(--tdh-surface-border);
        backdrop-filter: blur(16px) saturate(150%);
        -webkit-backdrop-filter: blur(16px) saturate(150%);
        box-shadow: 0 8px 32px rgba(0, 0, 0, 0.35);
    }

    .tdh-glass-strong {
        background: var(--tdh-surface-strong);
        border: 1px solid var(--tdh-surface-border);
        backdrop-filter: blur(20px) saturate(160%);
        -webkit-backdrop-filter: blur(20px) saturate(160%);
        box-shadow: 0 12px 40px rgba(0, 0, 0, 0.45);
    }

    /* Scroll Bar Style */
    ::-webkit-scrollbar {
        background: none;
        width: 16px;
        height: 16px;
    }

    ::-webkit-scrollbar-thumb {
        border: solid 0 rgb(0 0 0 / 0%);
        border-right-width: 4px;
        border-left-width: 4px;
        -webkit-border-radius: 9px 4px;
        -webkit-box-shadow: inset 0 0 0 1px var(--tdh-brand-700), inset 0 0 0 4px var(--tdh-brand-600);
    }

    ::-webkit-scrollbar-track-piece {
        margin: 4px 0;
    }

    ::-webkit-scrollbar-thumb:horizontal {
        border-right-width: 0;
        border-left-width: 0;
        border-top-width: 4px;
        border-bottom-width: 4px;
        -webkit-border-radius: 4px 9px;
    }

    ::-webkit-scrollbar-corner {
        background: transparent;
    }
`;
