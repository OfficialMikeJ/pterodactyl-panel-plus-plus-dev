<?php

namespace Pterodactyl\Http\Middleware;

use Closure;
use Illuminate\Http\Request;

/**
 * Guards dev-only endpoints. Requests are rejected with a 404 (not a 403 — the
 * endpoints should not reveal their existence) unless the panel is running on
 * the dev channel AND the authenticated user's email is on the
 * DEV_FEATURES_USERS whitelist.
 */
class DevFeaturesOnly
{
    public function handle(Request $request, Closure $next): mixed
    {
        if (config('touchdown.channel') !== 'dev') {
            abort(404);
        }

        $user = $request->user();
        if ($user === null) {
            abort(404);
        }

        $whitelist = array_filter(array_map(
            fn ($email) => strtolower(trim($email)),
            explode(',', (string) config('touchdown.dev_users')),
        ));

        if (!in_array(strtolower($user->email), $whitelist, true)) {
            abort(404);
        }

        return $next($request);
    }
}
