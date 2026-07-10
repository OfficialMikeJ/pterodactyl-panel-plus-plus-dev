<?php

namespace Pterodactyl\Http\Controllers\Api\Client;

use Carbon\Carbon;
use Illuminate\Support\Str;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Crypt;
use Pterodactyl\Models\StorageHost;
use Pterodactyl\Http\Requests\Api\Client\ClientApiRequest;

/**
 * Dev Lab storage management (dev build feature) — generates one-command
 * attach tokens and lists/detaches registered storage hosts. Gated by the
 * DevFeaturesOnly middleware on the /dev route group.
 */
class StorageController extends ClientApiController
{
    public function index(ClientApiRequest $request): JsonResponse
    {
        $hosts = StorageHost::query()
            ->where('user_id', $request->user()->id)
            ->orderByDesc('id')
            ->get()
            ->map(fn (StorageHost $host) => $this->toArray($host));

        return new JsonResponse(['data' => $hosts]);
    }

    /**
     * Creates a pending storage host + one-time attach token and returns the
     * single SSH command to run on the storage machine. The raw token is only
     * ever returned here — the panel stores a hash.
     */
    public function store(ClientApiRequest $request): JsonResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:60'],
        ]);

        $token = Str::random(48);

        $host = StorageHost::query()->create([
            'user_id' => $request->user()->id,
            'name' => $data['name'],
            'token_hash' => hash('sha256', $token),
            'status' => 'pending',
        ]);

        $command = sprintf(
            'curl -sSL %s/storage/attach.sh | sudo bash -s -- --token=%s',
            rtrim(config('app.url'), '/'),
            $token,
        );

        return new JsonResponse(['data' => array_merge($this->toArray($host), ['command' => $command])], 201);
    }

    /**
     * Registers a Windows/SMB network share as attached storage. Windows
     * Server machines do not run the attach agent — they expose storage the
     * native way, as a share the panel records here. The share password (if
     * any) is encrypted at rest and never returned by the API.
     */
    public function storeShare(ClientApiRequest $request): JsonResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:60'],
            'share_path' => ['required', 'string', 'max:191', 'regex:/^(\\\\\\\\|\/\/)[^\/\\\\]+[\/\\\\].+/'],
            'share_username' => ['nullable', 'string', 'max:191'],
            'share_password' => ['nullable', 'string', 'max:191'],
        ], [
            'share_path.regex' => 'The share path must be a UNC path such as \\\\server\\share.',
        ]);

        // Normalize //server/share to \\server\share for consistency.
        $sharePath = str_replace('/', '\\', $data['share_path']);
        $hostname = trim(explode('\\', ltrim($sharePath, '\\'))[0] ?? '');

        $host = StorageHost::query()->create([
            'user_id' => $request->user()->id,
            'name' => $data['name'],
            'token_hash' => hash('sha256', Str::random(48)),
            'status' => 'attached',
            'mode' => 'smb-share',
            'provider' => 'local',
            'nas_os' => 'windows-server',
            'hostname' => $hostname,
            'share_path' => $sharePath,
            'share_username' => $data['share_username'] ?? null,
            'share_password' => !empty($data['share_password']) ? Crypt::encryptString($data['share_password']) : null,
            'volumes' => [],
            'last_seen_at' => Carbon::now(),
        ]);

        return new JsonResponse(['data' => $this->toArray($host)], 201);
    }

    public function delete(ClientApiRequest $request, int $id): JsonResponse
    {
        StorageHost::query()
            ->where('user_id', $request->user()->id)
            ->where('id', $id)
            ->delete();

        return new JsonResponse([], JsonResponse::HTTP_NO_CONTENT);
    }

    private function toArray(StorageHost $host): array
    {
        return [
            'id' => $host->id,
            'name' => $host->name,
            'status' => $host->status,
            'mode' => $host->mode,
            'provider' => $host->provider,
            'nas_os' => $host->nas_os,
            'hostname' => $host->hostname,
            'ip' => $host->ip,
            'share_path' => $host->share_path,
            'share_username' => $host->share_username,
            'total_bytes' => $host->total_bytes,
            'free_bytes' => $host->free_bytes,
            'volumes' => $host->volumes ?? [],
            'last_seen_at' => $host->last_seen_at?->toIso8601String(),
            'created_at' => $host->created_at?->toIso8601String(),
        ];
    }
}
