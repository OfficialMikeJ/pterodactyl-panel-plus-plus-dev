<?php

namespace Pterodactyl\Services\Touchdown;

use Illuminate\Support\Collection;

/**
 * Some trophies care about more than "which event happened" — they care about
 * WHICH GAME was involved, or WHERE the node lives. This turns an activity log
 * entry's properties into extra, more specific counter keys.
 *
 * A single "server:delete" of an Arma 3 server therefore increments both
 * "server:delete" and "server:delete:arma", so generic and game-specific
 * trophies can both be defined against plain event strings.
 */
class TrophyQualifiers
{
    /**
     * Game slugs recognised for game-specific trophies. Matched case
     * insensitively against the egg name first, then the nest name, so both
     * "Arma 3" (egg) and "Minecraft" (nest, with a Paper/Forge egg) resolve.
     */
    private const GAMES = [
        'arma' => ['arma'],
        'squad' => ['squad'],
        'rust' => ['rust'],
        'minecraft' => ['minecraft', 'paper', 'spigot', 'forge', 'bukkit', 'purpur', 'fabric'],
        'icarus' => ['icarus'],
    ];

    /**
     * Locations that unlock the datacenter trophy. Matched against the node's
     * location short code and description.
     */
    private const TORONTO = ['toronto', 'yyz', 'ontario'];

    /**
     * @return string[] extra counter keys for this activity entry
     */
    public static function for(string $event, ?Collection $properties): array
    {
        if ($properties === null) {
            return [];
        }

        $keys = [];

        if ($event === 'server:delete' || $event === 'server:install') {
            $game = self::gameSlug(
                (string) $properties->get('egg', ''),
                (string) $properties->get('nest', ''),
            );

            if ($game !== null) {
                $keys[] = "{$event}:{$game}";
            }
        }

        if ($event === 'server:install') {
            $location = strtolower((string) $properties->get('location', ''));
            foreach (self::TORONTO as $needle) {
                if ($location !== '' && str_contains($location, $needle)) {
                    $keys[] = 'server:install:toronto';
                    break;
                }
            }
        }

        return $keys;
    }

    private static function gameSlug(string $egg, string $nest): ?string
    {
        $haystack = strtolower($egg . ' ' . $nest);

        foreach (self::GAMES as $slug => $needles) {
            foreach ($needles as $needle) {
                if (str_contains($haystack, $needle)) {
                    return $slug;
                }
            }
        }

        return null;
    }
}
