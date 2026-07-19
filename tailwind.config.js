const colors = require('tailwindcss/colors');

const gray = {
    50: 'hsl(216, 33%, 97%)',
    100: 'hsl(214, 15%, 91%)',
    200: 'hsl(210, 16%, 82%)',
    300: 'hsl(211, 13%, 65%)',
    400: 'hsl(211, 10%, 53%)',
    500: 'hsl(211, 12%, 43%)',
    600: 'hsl(209, 14%, 37%)',
    700: 'hsl(209, 18%, 30%)',
    800: 'hsl(209, 20%, 25%)',
    900: 'hsl(210, 24%, 16%)',
};

module.exports = {
    content: [
        './resources/scripts/**/*.{js,ts,tsx}',
    ],
    theme: {
        extend: {
            fontFamily: {
                header: ['"IBM Plex Sans"', '"Roboto"', 'system-ui', 'sans-serif'],
            },
            colors: {
                black: '#131a20',
                // "primary" and "neutral" are deprecated, prefer the use of "blue" and "gray"
                // in new code.
                primary: colors.blue,
                gray: gray,
                neutral: gray,
                cyan: colors.cyan,
                // Touch Down Hosting brand palette. Every shade resolves to a CSS custom
                // property so JSON themes can restyle the panel at runtime.
                brand: {
                    50: 'var(--tdh-brand-50)',
                    100: 'var(--tdh-brand-100)',
                    200: 'var(--tdh-brand-200)',
                    300: 'var(--tdh-brand-300)',
                    400: 'var(--tdh-brand-400)',
                    500: 'var(--tdh-brand-500)',
                    600: 'var(--tdh-brand-600)',
                    700: 'var(--tdh-brand-700)',
                    800: 'var(--tdh-brand-800)',
                    900: 'var(--tdh-brand-900)',
                },
            },
            boxShadow: {
                glow: '0 0 24px var(--tdh-glow)',
                'glow-sm': '0 0 12px var(--tdh-glow)',
            },
            fontSize: {
                '2xs': '0.625rem',
            },
            transitionDuration: {
                250: '250ms',
            },
            borderColor: theme => ({
                default: theme('colors.neutral.400', 'currentColor'),
            }),
        },
    },
    plugins: [
        // line-clamp is built into Tailwind CSS 3.3+ — no plugin needed.
        require('@tailwindcss/forms')({
            strategy: 'class',
        }),
    ]
};
