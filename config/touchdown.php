<?php

return [
    /*
    |--------------------------------------------------------------------------
    | Touch Down Hosting build information
    |--------------------------------------------------------------------------
    |
    | version  — public-facing version string shown in the panel UI.
    | channel  — "public" (customer-facing Alpha build, main branch) or
    |            "dev" (internal build, dev branch). Set by the installer.
    | build    — short git commit hash of the deployed code; refreshed by the
    |            installer/update scripts.
    |
    */
    // The version describes the CODE, so it is defined here rather than in
    // .env — otherwise a server that was installed at an older version keeps
    // reporting it forever, since updates never rewrite that variable.
    'version' => '1.1.0-alpha',
    'channel' => env('TDH_CHANNEL', 'public'),
    'build' => env('TDH_BUILD', 'local'),

    /*
    |--------------------------------------------------------------------------
    | Dev feature access
    |--------------------------------------------------------------------------
    |
    | Comma-separated list of account emails allowed to see dev-only panel
    | features. Only consulted when channel is "dev" — the public build never
    | exposes dev features regardless of this list.
    |
    */
    'dev_users' => env('DEV_FEATURES_USERS', ''),
];
