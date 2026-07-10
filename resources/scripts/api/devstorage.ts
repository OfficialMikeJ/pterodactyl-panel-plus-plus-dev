import http from '@/api/http';

export interface StorageVolume {
    device: string;
    size_bytes: number | null;
    fstype: string | null;
    mount: string | null;
    provider: string | null;
}

export interface StorageHost {
    id: number;
    name: string;
    status: 'pending' | 'attached';
    mode: 'local-device' | 'storage-server' | 'smb-share' | null;
    provider: string | null;
    nasOs: string | null;
    hostname: string | null;
    ip: string | null;
    sharePath: string | null;
    shareUsername: string | null;
    totalBytes: number;
    freeBytes: number;
    volumes: StorageVolume[];
    lastSeenAt: string | null;
    createdAt: string | null;
}

const toHost = (data: any): StorageHost => ({
    id: data.id,
    name: data.name,
    status: data.status,
    mode: data.mode,
    provider: data.provider,
    nasOs: data.nas_os,
    hostname: data.hostname,
    ip: data.ip,
    sharePath: data.share_path,
    shareUsername: data.share_username,
    totalBytes: data.total_bytes || 0,
    freeBytes: data.free_bytes || 0,
    volumes: data.volumes || [],
    lastSeenAt: data.last_seen_at,
    createdAt: data.created_at,
});

export const getStorageHosts = async (): Promise<StorageHost[]> => {
    const { data } = await http.get('/api/client/dev/storage');

    return (data.data || []).map(toHost);
};

export const createStorageHost = async (name: string): Promise<{ host: StorageHost; command: string }> => {
    const { data } = await http.post('/api/client/dev/storage', { name });

    return { host: toHost(data.data), command: data.data.command };
};

export interface CreateStorageShare {
    name: string;
    sharePath: string;
    shareUsername: string;
    sharePassword: string;
}

export const createStorageShare = async (share: CreateStorageShare): Promise<StorageHost> => {
    const { data } = await http.post('/api/client/dev/storage/share', {
        name: share.name,
        share_path: share.sharePath,
        share_username: share.shareUsername || null,
        share_password: share.sharePassword || null,
    });

    return toHost(data.data);
};

export const deleteStorageHost = (id: number): Promise<void> =>
    http.delete(`/api/client/dev/storage/${id}`).then(() => undefined);
