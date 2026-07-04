import React, { useEffect, useRef, useState } from 'react';
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome';
import {
    faCloud,
    faHdd,
    faNetworkWired,
    faPlug,
    faServer,
    faTerminal,
    faTrash,
} from '@fortawesome/free-solid-svg-icons';
import { useStoreState } from 'easy-peasy';
import styled, { keyframes } from 'styled-components/macro';
import tw from 'twin.macro';
import PageContentBlock from '@/components/elements/PageContentBlock';
import { NotFound } from '@/components/elements/ScreenBlock';
import Button from '@/components/elements/Button';
import Input from '@/components/elements/Input';
import Label from '@/components/elements/Label';
import CopyOnClick from '@/components/elements/CopyOnClick';
import Spinner from '@/components/elements/Spinner';
import FlashMessageRender from '@/components/FlashMessageRender';
import useFlash from '@/plugins/useFlash';
import { createStorageHost, deleteStorageHost, getStorageHosts, StorageHost } from '@/api/devstorage';

const providerMeta: Record<string, { label: string; color: string }> = {
    digitalocean: { label: 'DigitalOcean', color: '#0080ff' },
    hetzner: { label: 'Hetzner', color: '#d50c2d' },
    linode: { label: 'Linode', color: '#02b159' },
    ovh: { label: 'OVHcloud', color: '#123f6d' },
    local: { label: 'Local / Self-hosted', color: 'var(--tdh-brand-400)' },
    unknown: { label: 'Unknown', color: 'var(--tdh-text-muted)' },
};

const Card = styled.div`
    ${tw`rounded-lg p-5`};
    background: var(--tdh-surface-strong);
    border: 1px solid var(--tdh-surface-border);
    backdrop-filter: blur(18px) saturate(155%);
    -webkit-backdrop-filter: blur(18px) saturate(155%);
    box-shadow: 0 8px 32px rgba(0, 0, 0, 0.35);
`;

const CommandBlock = styled.code`
    ${tw`block rounded-lg p-3 mt-3 text-xs break-all cursor-pointer`};
    background: rgba(0, 0, 0, 0.45);
    border: 1px solid var(--tdh-brand-600);
    color: var(--tdh-brand-200);
    font-family: monospace;

    &:hover {
        box-shadow: 0 0 12px var(--tdh-glow);
    }
`;

const pulse = keyframes`
    0%, 100% { opacity: 1; }
    50% { opacity: 0.45; }
`;

const StatusPill = styled.span<{ $pending: boolean }>`
    ${tw`inline-flex items-center text-xs uppercase tracking-widest rounded-full px-3 py-1 font-bold`};
    color: ${(props) => (props.$pending ? 'var(--tdh-brand-400)' : '#4ade80')};
    border: 1px solid ${(props) => (props.$pending ? 'var(--tdh-brand-500)' : '#4ade80')};
    background: rgba(255, 255, 255, 0.04);
    ${(props) => props.$pending && 'animation-name: unset;'};
    animation: ${(props) => (props.$pending ? pulse : 'none')} 1.6s ease-in-out infinite;
`;

const ProviderChip = styled.span<{ $color: string }>`
    ${tw`inline-flex items-center text-xs rounded-full px-3 py-1 font-semibold ml-2`};
    color: ${(props) => props.$color};
    border: 1px solid ${(props) => props.$color};
    background: rgba(255, 255, 255, 0.04);
`;

const VolumeRow = styled.div`
    ${tw`flex items-center justify-between flex-wrap text-xs py-2`};
    color: var(--tdh-text);

    &:not(:last-of-type) {
        border-bottom: 1px solid var(--tdh-surface-border);
    }
`;

const formatBytes = (bytes: number | null): string => {
    if (!bytes || bytes <= 0) return '—';
    const units = ['B', 'KiB', 'MiB', 'GiB', 'TiB'];
    let value = bytes;
    let unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
        value /= 1024;
        unit++;
    }

    return `${value.toFixed(value >= 100 ? 0 : 1)} ${units[unit]}`;
};

/**
 * Storage (dev build feature) — attach additional storage by running a single
 * SSH command on any machine: extra local disks, dedicated storage servers, or
 * cloud volumes from Linode, Hetzner, OVH, DigitalOcean and friends.
 */
const StorageContainer = () => {
    const devFeatures = useStoreState((state) => state.settings.data?.touchdown?.devFeatures) || false;
    const { addFlash, clearFlashes, clearAndAddHttpError } = useFlash();

    const [hosts, setHosts] = useState<StorageHost[] | null>(null);
    const [name, setName] = useState('');
    const [command, setCommand] = useState<string | null>(null);
    const [creating, setCreating] = useState(false);
    const pollRef = useRef<number>();

    const refresh = () => getStorageHosts().then(setHosts).catch(console.error);

    useEffect(() => {
        if (!devFeatures) return;

        refresh();
        // Poll so the page updates live while the user runs the command over SSH.
        pollRef.current = window.setInterval(refresh, 10000);

        return () => window.clearInterval(pollRef.current);
    }, [devFeatures]);

    if (!devFeatures) {
        return <NotFound />;
    }

    const onCreate = () => {
        if (!name.trim()) return;

        setCreating(true);
        clearFlashes('storage');

        createStorageHost(name.trim())
            .then(({ command }) => {
                setCommand(command);
                setName('');
                refresh();
                addFlash({
                    key: 'storage',
                    type: 'success',
                    message: 'Attach command generated — it is shown only once, copy it now.',
                });
            })
            .catch((error) => clearAndAddHttpError({ key: 'storage', error }))
            .finally(() => setCreating(false));
    };

    const onDetach = (host: StorageHost) => {
        clearFlashes('storage');
        deleteStorageHost(host.id)
            .then(() => refresh())
            .catch((error) => clearAndAddHttpError({ key: 'storage', error }));
    };

    return (
        <PageContentBlock title={'Storage'}>
            <FlashMessageRender byKey={'storage'} css={tw`mb-4`} />
            <div css={tw`flex items-center justify-between flex-wrap mb-6`}>
                <h1 css={tw`text-2xl font-semibold`}>
                    <FontAwesomeIcon icon={faHdd} style={{ color: 'var(--tdh-brand-500)' }} css={tw`mr-3`} />
                    Storage
                    <span
                        css={tw`text-xs uppercase tracking-widest rounded-full px-3 py-1 ml-3 align-middle`}
                        style={{ color: 'var(--tdh-brand-400)', border: '1px solid var(--tdh-brand-500)' }}
                    >
                        Dev Preview
                    </span>
                </h1>
                <p css={tw`text-xs`} style={{ color: 'var(--tdh-text-muted)' }}>
                    Attach extra disks, storage servers, or cloud volumes (Linode, Hetzner, OVH, DigitalOcean) with a
                    single SSH command.
                </p>
            </div>

            <Card>
                <h2 css={tw`text-lg font-semibold mb-1`} style={{ color: 'var(--tdh-text)' }}>
                    <FontAwesomeIcon icon={faPlug} css={tw`mr-2`} style={{ color: 'var(--tdh-brand-500)' }} />
                    Attach New Storage
                </h2>
                <p css={tw`text-xs mb-4`} style={{ color: 'var(--tdh-text-muted)' }}>
                    Name the storage, generate the command, then run it as root on the machine holding the storage. The
                    agent auto-detects unmounted disks and cloud volumes — or registers the whole machine as a storage
                    server if it finds none. Detection is report-only; add <code>--mount</code> or <code>--format</code>{' '}
                    to also mount.
                </p>
                <div css={tw`flex items-end flex-wrap`}>
                    <div css={tw`flex-1 mr-4`} style={{ minWidth: '16rem' }}>
                        <Label>Storage Name</Label>
                        <Input
                            value={name}
                            placeholder={'e.g. Hetzner Volume 01'}
                            onChange={(e) => setName(e.currentTarget.value)}
                        />
                    </div>
                    <Button css={tw`mt-4`} isLoading={creating} disabled={creating || !name.trim()} onClick={onCreate}>
                        Generate Attach Command
                    </Button>
                </div>
                {command && (
                    <>
                        <CopyOnClick text={command}>
                            <CommandBlock>
                                <FontAwesomeIcon icon={faTerminal} css={tw`mr-2`} />
                                {command}
                            </CommandBlock>
                        </CopyOnClick>
                        <p css={tw`text-xs mt-2`} style={{ color: 'var(--tdh-text-muted)' }}>
                            Click the command to copy it. The token is shown only once — this page updates automatically
                            once the agent reports in.
                        </p>
                    </>
                )}
            </Card>

            <div css={tw`mt-8`}>
                <h2 css={tw`text-xl font-semibold mb-4`}>Attached Storage</h2>
                {!hosts ? (
                    <Spinner size={'large'} centered />
                ) : hosts.length === 0 ? (
                    <Card>
                        <p css={tw`text-sm`} style={{ color: 'var(--tdh-text-muted)' }}>
                            No storage attached yet — generate an attach command above to get started.
                        </p>
                    </Card>
                ) : (
                    <div css={tw`grid gap-4 grid-cols-1 lg:grid-cols-2`}>
                        {hosts.map((host) => {
                            const provider = providerMeta[host.provider || 'unknown'] || providerMeta.unknown;

                            return (
                                <Card key={host.id}>
                                    <div css={tw`flex items-center justify-between flex-wrap`}>
                                        <h3 css={tw`text-lg font-semibold`} style={{ color: 'var(--tdh-text)' }}>
                                            <FontAwesomeIcon
                                                icon={host.mode === 'storage-server' ? faServer : faHdd}
                                                css={tw`mr-2`}
                                                style={{ color: 'var(--tdh-brand-500)' }}
                                            />
                                            {host.name}
                                        </h3>
                                        <div css={tw`flex items-center`}>
                                            <StatusPill $pending={host.status === 'pending'}>
                                                {host.status === 'pending' ? 'Waiting for agent' : 'Attached'}
                                            </StatusPill>
                                            {host.status === 'attached' && (
                                                <ProviderChip $color={provider.color}>
                                                    <FontAwesomeIcon
                                                        icon={host.provider === 'local' ? faNetworkWired : faCloud}
                                                        css={tw`mr-1`}
                                                    />
                                                    {provider.label}
                                                </ProviderChip>
                                            )}
                                        </div>
                                    </div>
                                    {host.status === 'attached' && (
                                        <div css={tw`mt-3`}>
                                            <p css={tw`text-xs`} style={{ color: 'var(--tdh-text-muted)' }}>
                                                {host.hostname || 'unknown host'} ({host.ip || 'no ip'}) &mdash;{' '}
                                                {host.mode === 'storage-server'
                                                    ? `dedicated storage server, ${formatBytes(
                                                          host.freeBytes
                                                      )} free of ${formatBytes(host.totalBytes)}`
                                                    : `${host.volumes.length} volume(s) detected`}
                                            </p>
                                            {host.volumes.map((volume) => (
                                                <VolumeRow key={volume.device}>
                                                    <span css={tw`font-semibold`}>{volume.device}</span>
                                                    <span>{formatBytes(volume.size_bytes)}</span>
                                                    <span>{volume.fstype || 'unformatted'}</span>
                                                    <span style={{ color: 'var(--tdh-text-muted)' }}>
                                                        {volume.mount || 'not mounted'}
                                                    </span>
                                                </VolumeRow>
                                            ))}
                                        </div>
                                    )}
                                    <div css={tw`flex justify-end mt-4`}>
                                        <Button
                                            color={'red'}
                                            isSecondary
                                            size={'xsmall'}
                                            onClick={() => onDetach(host)}
                                        >
                                            <FontAwesomeIcon icon={faTrash} css={tw`mr-1`} />
                                            {host.status === 'pending' ? 'Cancel' : 'Detach'}
                                        </Button>
                                    </div>
                                </Card>
                            );
                        })}
                    </div>
                )}
            </div>
        </PageContentBlock>
    );
};

export default StorageContainer;
