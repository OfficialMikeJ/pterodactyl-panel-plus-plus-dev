<?php

namespace Pterodactyl\Services\Touchdown;

/**
 * The hardcoded Touch Down Hosting trophy registry. This file is the single
 * source of truth for every trophy in the panel — add new entries here and
 * they immediately become earnable, no database changes required.
 *
 * Tiers: bronze (25 EXP), silver (75 EXP), gold (150 EXP), platinum (400 EXP).
 *
 * `event` is the panel activity log event that advances the trophy and
 * `threshold` is how many times it must occur. The special key `completionist`
 * has no event — it is awarded automatically once every other trophy is owned.
 */
class TrophyRegistry
{
    public const TIER_EXP = [
        'bronze' => 25,
        'silver' => 75,
        'gold' => 150,
        'platinum' => 400,
    ];

    public const COMPLETIONIST_KEY = 'completionist';

    /**
     * @return array<int, array{key: string, name: string, description: string, tier: string, icon: string, event: string|null, threshold: int}>
     */
    public static function all(): array
    {
        return [
            // ── Bronze — first-time actions ─────────────────────────────────────
            ['key' => 'first-login', 'name' => 'Press Start', 'description' => 'Log in to the panel for the first time.', 'tier' => 'bronze', 'icon' => 'gamepad', 'event' => 'auth:success', 'threshold' => 1],
            ['key' => 'first-start', 'name' => 'Ignition', 'description' => 'Start a server for the first time.', 'tier' => 'bronze', 'icon' => 'play', 'event' => 'server:power.start', 'threshold' => 1],
            ['key' => 'first-command', 'name' => 'Console Cadet', 'description' => 'Send your first console command.', 'tier' => 'bronze', 'icon' => 'terminal', 'event' => 'server:console.command', 'threshold' => 1],
            ['key' => 'first-file-save', 'name' => 'Hello World', 'description' => 'Save a file for the first time.', 'tier' => 'bronze', 'icon' => 'file-code', 'event' => 'server:file.write', 'threshold' => 1],
            ['key' => 'first-folder', 'name' => 'Folder Founder', 'description' => 'Create your first directory.', 'tier' => 'bronze', 'icon' => 'folder', 'event' => 'server:file.create-directory', 'threshold' => 1],
            ['key' => 'first-rename', 'name' => 'Identity Shift', 'description' => 'Rename a file for the first time.', 'tier' => 'bronze', 'icon' => 'pen', 'event' => 'server:file.rename', 'threshold' => 1],
            ['key' => 'first-delete', 'name' => 'Clean Slate', 'description' => 'Delete a file for the first time.', 'tier' => 'bronze', 'icon' => 'trash', 'event' => 'server:file.delete', 'threshold' => 1],
            ['key' => 'first-compress', 'name' => 'Packrat', 'description' => 'Compress files into an archive for the first time.', 'tier' => 'bronze', 'icon' => 'file-archive', 'event' => 'server:file.compress', 'threshold' => 1],
            ['key' => 'first-decompress', 'name' => 'Unboxing', 'description' => 'Extract an archive for the first time.', 'tier' => 'bronze', 'icon' => 'box-open', 'event' => 'server:file.decompress', 'threshold' => 1],
            ['key' => 'first-download', 'name' => 'Data Courier', 'description' => 'Download a file from a server for the first time.', 'tier' => 'bronze', 'icon' => 'download', 'event' => 'server:file.download', 'threshold' => 1],
            ['key' => 'first-backup', 'name' => 'Save Point', 'description' => 'Create your first backup.', 'tier' => 'bronze', 'icon' => 'save', 'event' => 'server:backup.start', 'threshold' => 1],
            ['key' => 'first-restore', 'name' => 'Respawn', 'description' => 'Restore a backup for the first time.', 'tier' => 'bronze', 'icon' => 'undo', 'event' => 'server:backup.restore', 'threshold' => 1],
            ['key' => 'first-schedule', 'name' => 'Clockwork Rookie', 'description' => 'Create your first schedule.', 'tier' => 'bronze', 'icon' => 'clock', 'event' => 'server:schedule.create', 'threshold' => 1],
            ['key' => 'first-task', 'name' => 'Side Quest', 'description' => 'Add your first task to a schedule.', 'tier' => 'bronze', 'icon' => 'list', 'event' => 'server:task.create', 'threshold' => 1],
            ['key' => 'first-database', 'name' => 'Data Rookie', 'description' => 'Create your first database.', 'tier' => 'bronze', 'icon' => 'database', 'event' => 'server:database.create', 'threshold' => 1],
            ['key' => 'first-allocation', 'name' => 'Port Authority', 'description' => 'Create a network allocation for the first time.', 'tier' => 'bronze', 'icon' => 'network-wired', 'event' => 'server:allocation.create', 'threshold' => 1],
            ['key' => 'first-subuser', 'name' => 'Party Up', 'description' => 'Invite a subuser to one of your servers.', 'tier' => 'bronze', 'icon' => 'user-plus', 'event' => 'server:subuser.create', 'threshold' => 1],
            ['key' => 'first-server-rename', 'name' => 'Rebrand', 'description' => 'Rename one of your servers.', 'tier' => 'bronze', 'icon' => 'tag', 'event' => 'server:settings.rename', 'threshold' => 1],
            ['key' => 'first-api-key', 'name' => 'Modder', 'description' => 'Create your first API key.', 'tier' => 'bronze', 'icon' => 'code', 'event' => 'user:api-key.create', 'threshold' => 1],
            ['key' => 'first-ssh-key', 'name' => 'Keymaster', 'description' => 'Add your first SSH key.', 'tier' => 'bronze', 'icon' => 'key', 'event' => 'user:ssh-key.create', 'threshold' => 1],
            ['key' => 'two-factor', 'name' => 'Shields Up', 'description' => 'Enable two-factor authentication on your account.', 'tier' => 'bronze', 'icon' => 'shield-alt', 'event' => 'user:two-factor.create', 'threshold' => 1],
            ['key' => 'password-change', 'name' => 'New Combo', 'description' => 'Change your account password.', 'tier' => 'bronze', 'icon' => 'lock', 'event' => 'user:account.password-changed', 'threshold' => 1],
            ['key' => 'email-change', 'name' => 'Re-Routed', 'description' => 'Change your account email address.', 'tier' => 'bronze', 'icon' => 'envelope', 'event' => 'user:account.email-changed', 'threshold' => 1],
            ['key' => 'first-reinstall', 'name' => 'New Game+', 'description' => 'Reinstall a server for the first time.', 'tier' => 'bronze', 'icon' => 'redo', 'event' => 'server:reinstall', 'threshold' => 1],
            ['key' => 'first-startup-edit', 'name' => 'Tinkerer', 'description' => 'Edit a server startup variable for the first time.', 'tier' => 'bronze', 'icon' => 'sliders-h', 'event' => 'server:startup.edit', 'threshold' => 1],

            // ── Silver — grind milestones ───────────────────────────────────────
            ['key' => 'login-10', 'name' => 'Regular', 'description' => 'Log in to the panel 10 times.', 'tier' => 'silver', 'icon' => 'calendar-check', 'event' => 'auth:success', 'threshold' => 10],
            ['key' => 'start-25', 'name' => 'Seasoned Pilot', 'description' => 'Start servers 25 times.', 'tier' => 'silver', 'icon' => 'rocket', 'event' => 'server:power.start', 'threshold' => 25],
            ['key' => 'command-50', 'name' => 'Console Veteran', 'description' => 'Send 50 console commands.', 'tier' => 'silver', 'icon' => 'terminal', 'event' => 'server:console.command', 'threshold' => 50],
            ['key' => 'file-save-25', 'name' => 'Code Grinder', 'description' => 'Save files 25 times.', 'tier' => 'silver', 'icon' => 'keyboard', 'event' => 'server:file.write', 'threshold' => 25],
            ['key' => 'backup-10', 'name' => 'Safety Net', 'description' => 'Create 10 backups.', 'tier' => 'silver', 'icon' => 'life-ring', 'event' => 'server:backup.start', 'threshold' => 10],
            ['key' => 'schedule-5', 'name' => 'Automation Adept', 'description' => 'Create 5 schedules.', 'tier' => 'silver', 'icon' => 'robot', 'event' => 'server:schedule.create', 'threshold' => 5],
            ['key' => 'database-3', 'name' => 'Data Handler', 'description' => 'Create 3 databases.', 'tier' => 'silver', 'icon' => 'server', 'event' => 'server:database.create', 'threshold' => 3],
            ['key' => 'delete-25', 'name' => 'Demolition Crew', 'description' => 'Delete files 25 times.', 'tier' => 'silver', 'icon' => 'bomb', 'event' => 'server:file.delete', 'threshold' => 25],
            ['key' => 'compress-10', 'name' => 'Master Packer', 'description' => 'Compress files 10 times.', 'tier' => 'silver', 'icon' => 'boxes', 'event' => 'server:file.compress', 'threshold' => 10],
            ['key' => 'subuser-3', 'name' => 'Squad Leader', 'description' => 'Invite 3 subusers to your servers.', 'tier' => 'silver', 'icon' => 'users', 'event' => 'server:subuser.create', 'threshold' => 3],
            ['key' => 'restart-10', 'name' => 'Turbo Reboot', 'description' => 'Restart servers 10 times.', 'tier' => 'silver', 'icon' => 'sync', 'event' => 'server:power.restart', 'threshold' => 10],
            ['key' => 'stop-10', 'name' => 'Graceful Exit', 'description' => 'Stop servers 10 times.', 'tier' => 'silver', 'icon' => 'stop-circle', 'event' => 'server:power.stop', 'threshold' => 10],
            ['key' => 'rename-10', 'name' => 'Refactorer', 'description' => 'Rename files 10 times.', 'tier' => 'silver', 'icon' => 'pen', 'event' => 'server:file.rename', 'threshold' => 10],
            ['key' => 'task-10', 'name' => 'Quest Line', 'description' => 'Create 10 schedule tasks.', 'tier' => 'silver', 'icon' => 'tasks', 'event' => 'server:task.create', 'threshold' => 10],
            ['key' => 'schedule-exec-10', 'name' => 'Autopilot', 'description' => 'Manually execute schedules 10 times.', 'tier' => 'silver', 'icon' => 'magic', 'event' => 'server:schedule.execute', 'threshold' => 10],

            // ── Gold — mastery milestones ───────────────────────────────────────
            ['key' => 'login-50', 'name' => 'Dedicated', 'description' => 'Log in to the panel 50 times.', 'tier' => 'gold', 'icon' => 'medal', 'event' => 'auth:success', 'threshold' => 50],
            ['key' => 'start-100', 'name' => 'Ace Pilot', 'description' => 'Start servers 100 times.', 'tier' => 'gold', 'icon' => 'rocket', 'event' => 'server:power.start', 'threshold' => 100],
            ['key' => 'command-250', 'name' => 'Command Master', 'description' => 'Send 250 console commands.', 'tier' => 'gold', 'icon' => 'hat-wizard', 'event' => 'server:console.command', 'threshold' => 250],
            ['key' => 'file-save-100', 'name' => 'Code Machine', 'description' => 'Save files 100 times.', 'tier' => 'gold', 'icon' => 'microchip', 'event' => 'server:file.write', 'threshold' => 100],
            ['key' => 'backup-25', 'name' => 'Vault Keeper', 'description' => 'Create 25 backups.', 'tier' => 'gold', 'icon' => 'archive', 'event' => 'server:backup.start', 'threshold' => 25],
            ['key' => 'schedule-15', 'name' => 'Automation Master', 'description' => 'Create 15 schedules.', 'tier' => 'gold', 'icon' => 'cogs', 'event' => 'server:schedule.create', 'threshold' => 15],
            ['key' => 'delete-100', 'name' => 'Scorched Earth', 'description' => 'Delete files 100 times.', 'tier' => 'gold', 'icon' => 'fire', 'event' => 'server:file.delete', 'threshold' => 100],
            ['key' => 'subuser-10', 'name' => 'Guild Master', 'description' => 'Invite 10 subusers to your servers.', 'tier' => 'gold', 'icon' => 'chess-king', 'event' => 'server:subuser.create', 'threshold' => 10],

            // ── Meme tier — deleting specific games ─────────────────────────────
            ['key' => 'delete-arma', 'name' => "Arma'd By the Best", 'description' => 'Delete an Arma 3 server.', 'tier' => 'silver', 'icon' => 'bomb', 'event' => 'server:delete:arma', 'threshold' => 1],
            ['key' => 'delete-squad', 'name' => "Squad'd RPG", 'description' => 'Delete a Squad server.', 'tier' => 'silver', 'icon' => 'users', 'event' => 'server:delete:squad', 'threshold' => 1],
            ['key' => 'delete-rust', 'name' => 'Door Camper DB', 'description' => 'Delete a Rust server.', 'tier' => 'silver', 'icon' => 'fire', 'event' => 'server:delete:rust', 'threshold' => 1],
            ['key' => 'delete-minecraft', 'name' => "Mine'd to Death", 'description' => 'Delete a Minecraft server.', 'tier' => 'silver', 'icon' => 'bomb', 'event' => 'server:delete:minecraft', 'threshold' => 1],
            ['key' => 'delete-icarus', 'name' => 'ICARUS Made Me Do It', 'description' => 'Delete an ICARUS server.', 'tier' => 'silver', 'icon' => 'rocket', 'event' => 'server:delete:icarus', 'threshold' => 1],

            // ── Troll tier — questionable dedication ────────────────────────────
            ['key' => 'sir-clicksalot', 'name' => 'Sir Clicksalot', 'description' => 'Open server files 10 times. Just checking on them.', 'tier' => 'bronze', 'icon' => 'file-code', 'event' => 'server:file.read', 'threshold' => 10],
            ['key' => 'mrserverbosti', 'name' => 'MrServerbosti', 'description' => 'Set up and install 10 servers.', 'tier' => 'silver', 'icon' => 'server', 'event' => 'server:install', 'threshold' => 10],
            ['key' => 'fifty-servers', 'name' => '50 Servers or Die Trying', 'description' => 'Install 50 servers. Nobody asked you to.', 'tier' => 'gold', 'icon' => 'boxes', 'event' => 'server:install', 'threshold' => 50],
            ['key' => 'daserversbaby', 'name' => 'DaServersBaby', 'description' => 'Install 100 servers. Seek help.', 'tier' => 'platinum', 'icon' => 'chess-king', 'event' => 'server:install', 'threshold' => 100],
            ['key' => 'si6x-is-back', 'name' => 'The si6x is Back', 'description' => 'Set up a server in a Toronto, ON datacenter.', 'tier' => 'gold', 'icon' => 'network-wired', 'event' => 'server:install:toronto', 'threshold' => 1],
            ['key' => 'payments-too-hard', 'name' => '2 Hard 4 the Servers', 'description' => 'Fully configure the payment system — both gateways, switched on.', 'tier' => 'gold', 'icon' => 'lock', 'event' => 'touchdown:billing.configured', 'threshold' => 1],

            // ── Platinum — legendary feats ──────────────────────────────────────
            ['key' => 'command-1000', 'name' => 'Keyboard Warrior', 'description' => 'Send 1,000 console commands.', 'tier' => 'platinum', 'icon' => 'bolt', 'event' => 'server:console.command', 'threshold' => 1000],
            ['key' => self::COMPLETIONIST_KEY, 'name' => '100% Club', 'description' => 'Earn every other trophy in the panel.', 'tier' => 'platinum', 'icon' => 'trophy', 'event' => null, 'threshold' => 60],
        ];
    }

    /**
     * All trophies advanced by the given activity event.
     */
    public static function forEvent(string $event): array
    {
        return array_values(array_filter(self::all(), fn ($trophy) => $trophy['event'] === $event));
    }

    public static function find(string $key): ?array
    {
        foreach (self::all() as $trophy) {
            if ($trophy['key'] === $key) {
                return $trophy;
            }
        }

        return null;
    }

    public static function expFor(array $trophy): int
    {
        return self::TIER_EXP[$trophy['tier']] ?? 0;
    }

    /**
     * Total EXP required to reach a given level. Level 1 starts at 0 EXP and
     * each level costs progressively more (100, 200, 300, ... additional EXP).
     */
    public static function expForLevel(int $level): int
    {
        return 50 * ($level - 1) * $level;
    }

    public static function levelFromExp(int $exp): int
    {
        $level = 1;
        while (self::expForLevel($level + 1) <= $exp) {
            ++$level;
        }

        return $level;
    }
}
