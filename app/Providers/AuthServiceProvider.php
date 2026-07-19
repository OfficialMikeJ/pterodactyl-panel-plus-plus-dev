<?php

namespace Pterodactyl\Providers;

use Laravel\Sanctum\Sanctum;
use Pterodactyl\Models\ApiKey;
use Pterodactyl\Models\Server;
use Pterodactyl\Policies\ServerPolicy;
use Illuminate\Foundation\Support\Providers\AuthServiceProvider as ServiceProvider;

class AuthServiceProvider extends ServiceProvider
{
    /**
     * The model to policy mappings for the application.
     */
    protected $policies = [
        Server::class => ServerPolicy::class,
    ];

    public function boot(): void
    {
        Sanctum::usePersonalAccessTokenModel(ApiKey::class);

        // NOTE: the 30-day "Save my login" remember duration is configured via
        // the web guard's `remember` key in config/auth.php. Do NOT resolve
        // Auth::guard() here — building the session guard at boot requires the
        // encrypter (sessions are encrypted), which deadlocks
        // `php artisan key:generate` on fresh installs before APP_KEY exists.
    }
}
