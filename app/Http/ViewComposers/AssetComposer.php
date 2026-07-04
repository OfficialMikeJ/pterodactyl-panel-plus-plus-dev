<?php

namespace Pterodactyl\Http\ViewComposers;

use Illuminate\View\View;
use Pterodactyl\Services\Helpers\AssetHashService;

class AssetComposer
{
    /**
     * AssetComposer constructor.
     */
    public function __construct(private AssetHashService $assetHashService)
    {
    }

    /**
     * Provide access to the asset service in the views.
     */
    public function compose(View $view): void
    {
        $view->with('asset', $this->assetHashService);
        $view->with('siteConfiguration', [
            'name' => config('app.name') ?? 'Touch Down Hosting',
            'locale' => config('app.locale') ?? 'en',
            'recaptcha' => [
                'enabled' => config('recaptcha.enabled', false),
                'siteKey' => config('recaptcha.website_key') ?? '',
            ],
            'touchdown' => [
                'version' => config('touchdown.version'),
                'channel' => config('touchdown.channel'),
                'build' => config('touchdown.build'),
                'devFeatures' => $this->userHasDevFeatures(),
            ],
        ]);
    }

    /**
     * Dev-only panel features are limited to the dev channel AND accounts on
     * the DEV_FEATURES_USERS email whitelist.
     */
    private function userHasDevFeatures(): bool
    {
        if (config('touchdown.channel') !== 'dev') {
            return false;
        }

        $user = auth()->user();
        if ($user === null) {
            return false;
        }

        $whitelist = array_filter(array_map(
            fn ($email) => strtolower(trim($email)),
            explode(',', (string) config('touchdown.dev_users')),
        ));

        return in_array(strtolower($user->email), $whitelist, true);
    }
}
