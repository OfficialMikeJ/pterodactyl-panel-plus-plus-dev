<?php

namespace Pterodactyl\Http\Controllers\Api\Client;

use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Crypt;
use Pterodactyl\Http\Requests\Api\Client\ClientApiRequest;
use Pterodactyl\Contracts\Repository\SettingsRepositoryInterface;

class BillingController extends ClientApiController
{
    private const KEY_ENABLED = 'touchdown::billing:enabled';
    private const KEY_ORDER = 'touchdown::billing:order';
    private const KEY_STRIPE_PUBLISHABLE = 'touchdown::billing:stripe_publishable';
    private const KEY_STRIPE_SECRET = 'touchdown::billing:stripe_secret';
    private const KEY_PAYPAL_CLIENT = 'touchdown::billing:paypal_client_id';
    private const KEY_PAYPAL_SECRET = 'touchdown::billing:paypal_secret';

    public function __construct(private SettingsRepositoryInterface $settings)
    {
        parent::__construct();
    }

    /**
     * Returns the Services & Billing configuration. Secrets are never returned —
     * only whether each gateway has been configured.
     */
    public function index(ClientApiRequest $request): JsonResponse
    {
        $order = json_decode((string) $this->settings->get(self::KEY_ORDER, '[]'), true);

        return new JsonResponse([
            'data' => [
                'enabled' => (bool) $this->settings->get(self::KEY_ENABLED, false),
                'order' => is_array($order) ? $order : [],
                'gateways' => [
                    'stripe' => [
                        'publishable_key' => (string) $this->settings->get(self::KEY_STRIPE_PUBLISHABLE, ''),
                        'configured' => !empty($this->settings->get(self::KEY_STRIPE_SECRET, '')),
                    ],
                    'paypal' => [
                        'client_id' => (string) $this->settings->get(self::KEY_PAYPAL_CLIENT, ''),
                        'configured' => !empty($this->settings->get(self::KEY_PAYPAL_SECRET, '')),
                    ],
                ],
            ],
        ]);
    }

    /**
     * Updates the Services & Billing settings. Root administrators only. Secret
     * keys are encrypted at rest; submitting an empty secret keeps the existing one.
     */
    public function updateSettings(ClientApiRequest $request): JsonResponse
    {
        $this->requireRootAdmin($request);

        $data = $request->validate([
            'enabled' => ['required', 'boolean'],
            'stripe_publishable_key' => ['nullable', 'string', 'max:191'],
            'stripe_secret_key' => ['nullable', 'string', 'max:191'],
            'paypal_client_id' => ['nullable', 'string', 'max:191'],
            'paypal_secret' => ['nullable', 'string', 'max:191'],
        ]);

        $this->settings->set(self::KEY_ENABLED, $data['enabled'] ? '1' : '');
        $this->settings->set(self::KEY_STRIPE_PUBLISHABLE, $data['stripe_publishable_key'] ?? '');
        $this->settings->set(self::KEY_PAYPAL_CLIENT, $data['paypal_client_id'] ?? '');

        if (!empty($data['stripe_secret_key'])) {
            $this->settings->set(self::KEY_STRIPE_SECRET, Crypt::encryptString($data['stripe_secret_key']));
        }

        if (!empty($data['paypal_secret'])) {
            $this->settings->set(self::KEY_PAYPAL_SECRET, Crypt::encryptString($data['paypal_secret']));
        }

        // Touch Down Hosting: services enabled with BOTH gateways holding a
        // publishable/client id and a stored secret means billing is fully
        // wired up — worth a trophy.
        $fullyConfigured = $data['enabled']
            && !empty($this->settings->get(self::KEY_STRIPE_PUBLISHABLE, ''))
            && !empty($this->settings->get(self::KEY_STRIPE_SECRET, ''))
            && !empty($this->settings->get(self::KEY_PAYPAL_CLIENT, ''))
            && !empty($this->settings->get(self::KEY_PAYPAL_SECRET, ''));

        if ($fullyConfigured) {
            try {
                \Pterodactyl\Facades\Activity::event('touchdown:billing.configured')->log();
            } catch (\Throwable) {
                // Trophies must never break a settings save.
            }
        }

        return $this->index($request);
    }

    /**
     * Persists the drag-and-drop ordering of the pricing cards. Root
     * administrators only.
     */
    public function updateOrder(ClientApiRequest $request): JsonResponse
    {
        $this->requireRootAdmin($request);

        $data = $request->validate([
            'order' => ['required', 'array', 'max:50'],
            'order.*' => ['string', 'max:64'],
        ]);

        $this->settings->set(self::KEY_ORDER, json_encode(array_values($data['order'])));

        return $this->index($request);
    }

    private function requireRootAdmin(ClientApiRequest $request): void
    {
        if (!$request->user()?->root_admin) {
            abort(403, 'You do not have permission to manage billing settings.');
        }
    }
}
