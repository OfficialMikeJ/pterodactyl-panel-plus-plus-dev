import React, { forwardRef } from 'react';
import { Form } from 'formik';
import { useStoreState } from 'easy-peasy';
import styled from 'styled-components/macro';
import { breakpoint } from '@/theme';
import FlashMessageRender from '@/components/FlashMessageRender';
import tw from 'twin.macro';
import BrandLogo from '@/components/touchdown/BrandLogo';
import DiscordButton from '@/components/touchdown/DiscordButton';

type Props = React.DetailedHTMLProps<React.FormHTMLAttributes<HTMLFormElement>, HTMLFormElement> & {
    title?: string;
};

const Container = styled.div`
    ${breakpoint('sm')`
        ${tw`w-4/5 mx-auto`}
    `};

    ${breakpoint('md')`
        ${tw`p-10`}
    `};

    ${breakpoint('lg')`
        ${tw`w-3/5`}
    `};

    ${breakpoint('xl')`
        ${tw`w-full`}
        max-width: 700px;
    `};
`;

const GlassCard = styled.div`
    ${tw`md:flex w-full rounded-lg p-6 mx-1`};
    background: var(--tdh-surface-strong);
    border: 1px solid var(--tdh-surface-border);
    backdrop-filter: blur(20px) saturate(160%);
    -webkit-backdrop-filter: blur(20px) saturate(160%);
    box-shadow: 0 12px 48px rgba(0, 0, 0, 0.5), 0 0 32px var(--tdh-glow);
`;

/**
 * Required attribution when the floating reCAPTCHA badge is hidden (see the
 * .grecaptcha-badge rule in GlobalStylesheet). Only rendered when reCAPTCHA
 * is actually enabled for this panel.
 */
const RecaptchaNotice = () => {
    const enabled = useStoreState((state) => state.settings.data?.recaptcha?.enabled);

    if (!enabled) return null;

    return (
        <p css={tw`text-center mt-4`} style={{ color: 'var(--tdh-text-muted)', fontSize: '0.6875rem' }}>
            Protected by reCAPTCHA &mdash; Google{' '}
            <a
                href={'https://policies.google.com/privacy'}
                target={'_blank'}
                rel={'noopener noreferrer'}
                css={tw`no-underline`}
                style={{ color: 'var(--tdh-text-muted)', textDecoration: 'underline' }}
            >
                Privacy Policy
            </a>{' '}
            and{' '}
            <a
                href={'https://policies.google.com/terms'}
                target={'_blank'}
                rel={'noopener noreferrer'}
                css={tw`no-underline`}
                style={{ color: 'var(--tdh-text-muted)', textDecoration: 'underline' }}
            >
                Terms of Service
            </a>{' '}
            apply.
        </p>
    );
};

export default forwardRef<HTMLFormElement, Props>(({ title, ...props }, ref) => (
    <Container>
        {title && (
            <h2 css={tw`text-3xl text-center font-medium py-4`} style={{ color: 'var(--tdh-text)' }}>
                {title}
            </h2>
        )}
        <FlashMessageRender css={tw`mb-2 px-1`} />
        <Form {...props} ref={ref}>
            <GlassCard>
                <div css={tw`flex-none select-none mb-6 md:mb-0 self-center md:pr-6`}>
                    <div css={tw`block w-48 md:w-64 mx-auto flex justify-center`}>
                        <BrandLogo variant={'login'} />
                    </div>
                </div>
                <div css={tw`flex-1`}>{props.children}</div>
            </GlassCard>
        </Form>
        <p css={tw`text-center text-xs mt-6`} style={{ color: 'var(--tdh-text-muted)' }}>
            Having trouble logging in? Join our Discord and we&apos;ll help you out.
        </p>
        <DiscordButton css={tw`mt-3`} />
        <RecaptchaNotice />
        <p css={tw`text-center text-xs mt-4`} style={{ color: 'var(--tdh-text-muted)' }}>
            &copy; {new Date().getFullYear()} <span style={{ color: 'var(--tdh-brand-400)' }}>Touch Down Hosting</span>
            &nbsp;&mdash; All rights reserved.
        </p>
    </Container>
));
