import React, { useEffect, useState } from 'react';
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome';
import { faFlask, faServer, faToggleOn, faTrophy } from '@fortawesome/free-solid-svg-icons';
import { useStoreState } from 'easy-peasy';
import styled from 'styled-components/macro';
import tw from 'twin.macro';
import http from '@/api/http';
import PageContentBlock from '@/components/elements/PageContentBlock';
import { NotFound } from '@/components/elements/ScreenBlock';
import Button from '@/components/elements/Button';
import Switch from '@/components/elements/Switch';
import Spinner from '@/components/elements/Spinner';
import { tierColors } from '@/touchdown/icons';

interface BuildInfo {
    version: string;
    channel: string;
    build: string;
    php: string;
    laravel: string;
    cache_driver: string;
    queue_driver: string;
    session_driver: string;
    users: number;
    servers: number;
    trophies_awarded: number;
}

const FLAGS_KEY = 'tdh-dev-flags';

interface DevFlags {
    compactRows: boolean;
    verboseLogging: boolean;
}

const loadFlags = (): DevFlags => {
    try {
        return { compactRows: false, verboseLogging: false, ...JSON.parse(localStorage.getItem(FLAGS_KEY) || '{}') };
    } catch {
        return { compactRows: false, verboseLogging: false };
    }
};

const Card = styled.div`
    ${tw`rounded-lg p-5`};
    background: var(--tdh-surface-strong);
    border: 1px solid var(--tdh-surface-border);
    backdrop-filter: blur(18px) saturate(155%);
    -webkit-backdrop-filter: blur(18px) saturate(155%);
    box-shadow: 0 8px 32px rgba(0, 0, 0, 0.35);
`;

const Row = styled.div`
    ${tw`flex items-center justify-between text-sm py-2`};
    color: var(--tdh-text);

    &:not(:last-of-type) {
        border-bottom: 1px solid var(--tdh-surface-border);
    }

    & > span:first-of-type {
        color: var(--tdh-text-muted);
    }

    & > span:last-of-type {
        ${tw`font-semibold`};
    }
`;

const PreviewToast = styled.div`
    ${tw`fixed bottom-0 right-0 m-4 flex items-center rounded-lg p-4`};
    z-index: 9990;
    min-width: 20rem;
    background: var(--tdh-surface-strong);
    border: 1px solid ${tierColors.gold};
    backdrop-filter: blur(20px) saturate(160%);
    box-shadow: 0 12px 40px rgba(0, 0, 0, 0.5), 0 0 20px var(--tdh-glow);
`;

/**
 * Dev Lab — the internal staging ground for features before they ship to the
 * public build. Rendered only on the dev channel for whitelisted accounts;
 * everyone else gets a 404 (matching the backend behaviour).
 */
const DevLabContainer = () => {
    const devFeatures = useStoreState((state) => state.settings.data?.touchdown?.devFeatures) || false;
    const [info, setInfo] = useState<BuildInfo | null>(null);
    const [flags, setFlags] = useState<DevFlags>(loadFlags);
    const [previewToast, setPreviewToast] = useState(false);

    useEffect(() => {
        if (!devFeatures) return;

        http.get('/api/client/dev/build')
            .then(({ data }) => setInfo(data.data))
            .catch(console.error);
    }, [devFeatures]);

    if (!devFeatures) {
        return <NotFound />;
    }

    const toggleFlag = (key: keyof DevFlags) => {
        setFlags((current) => {
            const next = { ...current, [key]: !current[key] };
            localStorage.setItem(FLAGS_KEY, JSON.stringify(next));
            return next;
        });
    };

    const showPreviewToast = () => {
        setPreviewToast(true);
        setTimeout(() => setPreviewToast(false), 5000);
    };

    return (
        <PageContentBlock title={'Dev Lab'}>
            <div css={tw`flex items-center justify-between flex-wrap mb-6`}>
                <h1 css={tw`text-2xl font-semibold`}>
                    <FontAwesomeIcon icon={faFlask} style={{ color: 'var(--tdh-brand-500)' }} css={tw`mr-3`} />
                    Dev Lab
                </h1>
                <p css={tw`text-xs`} style={{ color: 'var(--tdh-text-muted)' }}>
                    Internal build only — visible to whitelisted dev accounts. Features graduate from here to the public
                    roadmap.
                </p>
            </div>
            <div css={tw`grid gap-6 grid-cols-1 lg:grid-cols-2`}>
                <Card>
                    <h2 css={tw`text-lg font-semibold mb-2`} style={{ color: 'var(--tdh-text)' }}>
                        <FontAwesomeIcon icon={faServer} css={tw`mr-2`} style={{ color: 'var(--tdh-brand-500)' }} />
                        Build &amp; Environment
                    </h2>
                    {!info ? (
                        <Spinner centered />
                    ) : (
                        <>
                            <Row>
                                <span>Panel version</span>
                                <span style={{ color: 'var(--tdh-brand-400)' }}>
                                    v{info.version} ({info.channel})
                                </span>
                            </Row>
                            <Row>
                                <span>Build commit</span>
                                <span>{info.build}</span>
                            </Row>
                            <Row>
                                <span>PHP / Laravel</span>
                                <span>
                                    {info.php} / {info.laravel}
                                </span>
                            </Row>
                            <Row>
                                <span>Cache / Queue / Session</span>
                                <span>
                                    {info.cache_driver} / {info.queue_driver} / {info.session_driver}
                                </span>
                            </Row>
                            <Row>
                                <span>Users / Servers</span>
                                <span>
                                    {info.users} / {info.servers}
                                </span>
                            </Row>
                            <Row>
                                <span>Trophies awarded (all users)</span>
                                <span>{info.trophies_awarded}</span>
                            </Row>
                        </>
                    )}
                </Card>
                <div>
                    <Card>
                        <h2 css={tw`text-lg font-semibold mb-2`} style={{ color: 'var(--tdh-text)' }}>
                            <FontAwesomeIcon icon={faTrophy} css={tw`mr-2`} style={{ color: 'var(--tdh-brand-500)' }} />
                            Trophy Toast Preview
                        </h2>
                        <p css={tw`text-xs mb-3`} style={{ color: 'var(--tdh-text-muted)' }}>
                            Renders a sample trophy toast so notification styling can be tuned without earning anything.
                        </p>
                        <Button color={'white'} onClick={showPreviewToast}>
                            Preview Toast
                        </Button>
                    </Card>
                    <Card css={tw`mt-6`}>
                        <h2 css={tw`text-lg font-semibold mb-2`} style={{ color: 'var(--tdh-text)' }}>
                            <FontAwesomeIcon
                                icon={faToggleOn}
                                css={tw`mr-2`}
                                style={{ color: 'var(--tdh-brand-500)' }}
                            />
                            Experimental Flags
                        </h2>
                        <p css={tw`text-xs mb-3`} style={{ color: 'var(--tdh-text-muted)' }}>
                            Local-only scaffolding for in-development features. Stored in this browser.
                        </p>
                        <div css={tw`mb-3`}>
                            <Switch
                                name={'flag_compact'}
                                label={'Compact server rows'}
                                description={'Prototype for a denser dashboard layout.'}
                                defaultChecked={flags.compactRows}
                                onChange={() => toggleFlag('compactRows')}
                            />
                        </div>
                        <Switch
                            name={'flag_verbose'}
                            label={'Verbose console logging'}
                            description={'Extra debug output from panel API calls in the browser console.'}
                            defaultChecked={flags.verboseLogging}
                            onChange={() => toggleFlag('verboseLogging')}
                        />
                    </Card>
                </div>
            </div>
            {previewToast && (
                <PreviewToast>
                    <div
                        css={tw`flex items-center justify-center rounded-full flex-shrink-0 mr-4 w-12 h-12`}
                        style={{
                            color: tierColors.gold,
                            border: `2px solid ${tierColors.gold}`,
                            background: 'rgba(255,255,255,0.07)',
                        }}
                    >
                        <FontAwesomeIcon icon={faTrophy} size={'lg'} />
                    </div>
                    <div css={tw`flex-1`}>
                        <p css={tw`text-xs uppercase tracking-widest`} style={{ color: tierColors.gold }}>
                            Gold Trophy Earned!
                        </p>
                        <p css={tw`font-semibold`} style={{ color: 'var(--tdh-text)' }}>
                            Dev Lab Rat
                        </p>
                        <p css={tw`text-xs`} style={{ color: 'var(--tdh-text-muted)' }}>
                            Previewed a toast from the Dev Lab.
                        </p>
                    </div>
                    <div css={tw`ml-3 text-sm font-bold`} style={{ color: 'var(--tdh-brand-400)' }}>
                        +150 EXP
                    </div>
                </PreviewToast>
            )}
        </PageContentBlock>
    );
};

export default DevLabContainer;
