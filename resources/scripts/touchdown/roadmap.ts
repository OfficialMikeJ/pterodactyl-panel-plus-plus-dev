/**
 * Touch Down Hosting — public roadmap (the "To Do" list for the Public build).
 *
 * Like the Dev-Blogs, this file is the ONLY place roadmap content lives and it
 * renders read-only in the panel. Edit this file externally and rebuild to
 * update it. Items move planned → in-progress → done as work lands.
 */
export type RoadmapStatus = 'planned' | 'in-progress' | 'done';

export interface RoadmapItem {
    title: string;
    description: string;
    status: RoadmapStatus;
}

export const roadmap: RoadmapItem[] = [
    {
        title: 'Global reskin & glass morphism',
        description: 'Black/white/orange redesign with the signature glass finish across the whole panel.',
        status: 'done',
    },
    {
        title: 'Trophy & EXP system (50 trophies)',
        description: 'Bronze, Silver, Gold and Platinum trophies with EXP levels and toast notifications.',
        status: 'done',
    },
    {
        title: 'Theming system with custom JSON themes',
        description: 'Four built-in themes plus drop-in .json themes in public/themes.',
        status: 'done',
    },
    {
        title: 'One-command storage attach',
        description:
            'Attach extra disks, cloud volumes (Linode, Hetzner, OVH, DigitalOcean), NAS systems (HexOS, TrueNAS, OpenMediaVault, CasaOS, Unraid) and Windows shares with a single command or a few clicks.',
        status: 'in-progress',
    },
    {
        title: 'More trophies (51+)',
        description:
            'Eleven new trophies for game-specific server deletions, install milestones, datacenter deployments and payment setup — 61 in total.',
        status: 'done',
    },
    {
        title: 'Seasonal & event trophies',
        description: 'Limited-time trophies tied to holidays, launches and community events.',
        status: 'planned',
    },
    {
        title: 'Stripe checkout flow',
        description: 'Full checkout for the Services pricing cards using your configured Stripe keys.',
        status: 'planned',
    },
    {
        title: 'PayPal checkout flow',
        description: 'PayPal-based checkout for the Services pricing cards.',
        status: 'planned',
    },
    {
        title: 'Trophy email notifications',
        description: 'Optional email digests when big trophies (Gold/Platinum) are earned.',
        status: 'planned',
    },
    {
        title: 'Mobile UI polish',
        description: 'Tightened layouts for the trophy grid, pricing cards and dashboard on small screens.',
        status: 'planned',
    },
];
