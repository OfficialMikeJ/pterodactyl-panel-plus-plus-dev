<?php

namespace Pterodactyl\Http\Controllers\Api\Client;

use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;
use Pterodactyl\Http\Requests\Api\Client\ClientApiRequest;

/**
 * Dev Lab endpoints — dev channel + whitelisted accounts only (enforced by the
 * DevFeaturesOnly middleware on the route group).
 */
class DevController extends ClientApiController
{
    /**
     * Build & environment diagnostics for the Dev Lab.
     */
    public function build(ClientApiRequest $request): JsonResponse
    {
        return new JsonResponse([
            'data' => [
                'version' => config('touchdown.version'),
                'channel' => config('touchdown.channel'),
                'build' => config('touchdown.build'),
                'php' => PHP_VERSION,
                'laravel' => app()->version(),
                'cache_driver' => config('cache.default'),
                'queue_driver' => config('queue.default'),
                'session_driver' => config('session.driver'),
                'users' => (int) DB::table('users')->count(),
                'servers' => (int) DB::table('servers')->count(),
                'trophies_awarded' => (int) DB::table('user_trophies')->count(),
            ],
        ]);
    }
}
