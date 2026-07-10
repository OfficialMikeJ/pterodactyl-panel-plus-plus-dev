<?php

namespace Pterodactyl\Http\Controllers\Base;

use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Illuminate\Http\JsonResponse;
use Pterodactyl\Models\StorageHost;
use Pterodactyl\Http\Controllers\Controller;

/**
 * Public endpoints backing the Touch Down Hosting one-command storage attach
 * agent (dev build feature). The script itself is not secret — the one-time
 * attach token passed to it is what authenticates the ingest call.
 */
class StorageAgentController extends Controller
{
    /**
     * Serves the storage attach agent script with this panel's URL baked in,
     * so users can run: curl -sSL https://panel/storage/attach.sh | sudo bash -s -- --token=...
     */
    public function script(): Response
    {
        $script = file_get_contents(base_path('resources/agent/storage-attach.sh'));
        $script = str_replace('__PANEL_URL__', rtrim(config('app.url'), '/'), $script);

        return new Response($script, 200, ['Content-Type' => 'text/plain; charset=utf-8']);
    }

    /**
     * Receives the detection report from the agent. Authenticated purely by the
     * one-time attach token generated on the panel's Storage page.
     */
    public function ingest(Request $request): JsonResponse
    {
        $data = $request->validate([
            'token' => ['required', 'string', 'max:191'],
            'hostname' => ['nullable', 'string', 'max:191'],
            'ip' => ['nullable', 'string', 'max:64'],
            'provider' => ['nullable', 'string', 'max:32'],
            'nas_os' => ['nullable', 'string', 'max:64'],
            'mode' => ['required', 'string', 'in:local-device,storage-server'],
            'total_bytes' => ['nullable', 'integer', 'min:0'],
            'free_bytes' => ['nullable', 'integer', 'min:0'],
            'volumes' => ['nullable', 'array', 'max:32'],
            'volumes.*.device' => ['required_with:volumes', 'string', 'max:64'],
            'volumes.*.size_bytes' => ['nullable', 'integer', 'min:0'],
            'volumes.*.fstype' => ['nullable', 'string', 'max:32'],
            'volumes.*.mount' => ['nullable', 'string', 'max:191'],
            'volumes.*.provider' => ['nullable', 'string', 'max:32'],
        ]);

        $host = StorageHost::query()->where('token_hash', hash('sha256', $data['token']))->first();
        if ($host === null) {
            return new JsonResponse(['ok' => false, 'error' => 'Invalid attach token.'], 404);
        }

        $host->update([
            'status' => 'attached',
            'mode' => $data['mode'],
            'provider' => $data['provider'] ?? 'unknown',
            'nas_os' => $data['nas_os'] ?? null,
            'hostname' => $data['hostname'] ?? null,
            'ip' => $data['ip'] ?? null,
            'total_bytes' => $data['total_bytes'] ?? 0,
            'free_bytes' => $data['free_bytes'] ?? 0,
            'volumes' => $data['volumes'] ?? [],
            'last_seen_at' => Carbon::now(),
        ]);

        return new JsonResponse(['ok' => true, 'name' => $host->name]);
    }
}
