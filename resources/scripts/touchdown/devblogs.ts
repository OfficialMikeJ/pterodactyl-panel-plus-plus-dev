/**
 * Touch Down Hosting Dev-Blogs.
 *
 * This file is the ONLY place Dev-Blog content lives. The Dev-Blogs page in the
 * panel renders this list read-only — there is intentionally no way to add or
 * edit posts from inside the panel. To publish an update, edit this file and
 * rebuild the panel assets.
 */
export type DevBlogType = 'feature' | 'hotfix' | 'news';

export interface DevBlogPost {
    id: string;
    date: string;
    title: string;
    type: DevBlogType;
    tags: string[];
    paragraphs: string[];
}

export const devBlogPosts: DevBlogPost[] = [
    {
        id: 'v1-1-0-alpha',
        date: '2026-07-20',
        title: 'v1.1.0-alpha — Meme Trophies, Theme Menu Fix',
        type: 'feature',
        tags: ['release', 'trophies', 'themes'],
        paragraphs: [
            'Version 1.1.0-alpha is out. The headline addition: eleven new trophies, because fifty was clearly not enough.',
            "Five of them are for deleting servers of specific games — Arma'd By the Best, Squad'd RPG, Door Camper DB, Mine'd to Death, and ICARUS Made Me Do It. The other six reward questionable dedication: Sir Clicksalot for opening server files ten times, MrServerbosti for setting up ten servers, 50 Servers or Die Trying, DaServersBaby for a hundred, The si6x is Back for deploying into a Toronto datacenter, and 2 Hard 4 the Servers for fully wiring up the payment system.",
            'Making those work meant teaching the panel to record things it never logged before — server deletions (including which game), server installs (including which datacenter), and payment configuration. All of that logging is fail-safe: a trophy can never interrupt a deletion, an install, or a settings save.',
            'Also fixed: the theme picker in the navigation bar opened but showed nothing. The glass effect on the navigation bar was quietly clipping the menu out of existence. It now renders above everything, closes on Escape, and the palette button toggles it properly.',
        ],
    },
    {
        id: 'node-fqdn-red-heart',
        date: '2026-07-20',
        title: 'Node Setup: Matching the FQDN to How You Actually Reach It',
        type: 'news',
        tags: ['nodes', 'wings', 'setup'],
        paragraphs: [
            'If a node shows a red heart while Wings is clearly running and healthy, the cause is almost always the node FQDN. The heartbeat check runs in your browser — not on the panel server — so the FQDN has to be an address your browser can actually reach, and it has to match how Wings is serving.',
            "On a LAN with plain HTTP and no certificate, set the node FQDN to the machine's IP address (for example 192.168.2.26) and turn Communicate over SSL off. Wings listens on all interfaces regardless, so no change to config.yml is needed.",
            'Once the panel is behind a reverse proxy such as Nginx Proxy Manager with a real certificate, switch the node to node.example.com (replacing example.com with your own domain) and turn SSL on. That domain must resolve to the node machine — a domain pointing at your public IP will be forwarded by your router to whichever box owns ports 80 and 443, which may not be the node at all.',
            'One trap worth knowing: browsers block a secure page from calling a plain-HTTP node. When the panel moves to HTTPS, the node has to move with it, otherwise a previously working IP-based node goes red.',
        ],
    },
    {
        id: 'welcome-to-touch-down-hosting',
        date: '2026-07-03',
        title: 'Welcome to Touch Down Hosting!',
        type: 'news',
        tags: ['launch', 'welcome'],
        paragraphs: [
            'Welcome to the brand new Touch Down Hosting panel! This is our custom-built control panel experience with a fully redesigned interface featuring our signature black, white and orange look with a glass morphism finish.',
            'From here you can manage your game servers, track your trophies and EXP, customize your panel theme, and keep up with everything we are working on — right on this page.',
            'Thanks for being here at kickoff. This is just the beginning.',
        ],
    },
    {
        id: 'trophy-system-launch',
        date: '2026-07-03',
        title: 'Trophy & EXP System is Live',
        type: 'feature',
        tags: ['trophies', 'exp', 'gamification'],
        paragraphs: [
            'The panel now has a full trophy and EXP system! Fifty trophies across Bronze, Silver, Gold and Platinum tiers are waiting to be earned for everyday actions — starting servers, saving files, creating backups, setting up schedules and much more.',
            'Every trophy grants EXP that raises your panel level. Earn all forty-nine standard trophies and the final Platinum "100% Club" trophy unlocks automatically.',
            'More trophies will be added over time — keep an eye on this page for announcements.',
        ],
    },
    {
        id: 'theming-system',
        date: '2026-07-03',
        title: 'Four Themes Out of the Box + Custom JSON Themes',
        type: 'feature',
        tags: ['themes', 'customization'],
        paragraphs: [
            'You can now reskin the entire panel from the palette icon in the navigation bar. Four themes ship out of the box: Cool Orange (the default), Cool Blue Ocean, Cool Green Mint and Cool Silk Purple.',
            'Panel owners can add fully custom themes at any time by dropping a .json theme file into the public/themes directory — no rebuild required. The theme picker discovers them automatically.',
        ],
    },
];
