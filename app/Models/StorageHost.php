<?php

namespace Pterodactyl\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Touch Down Hosting — a storage host registered via the one-command SSH
 * attach agent (dev build feature).
 *
 * @property int $id
 * @property int $user_id
 * @property string $name
 * @property string $token_hash
 * @property string $status
 * @property string|null $mode
 * @property string|null $provider
 * @property string|null $hostname
 * @property string|null $ip
 * @property int|null $total_bytes
 * @property int|null $free_bytes
 * @property array|null $volumes
 * @property \Carbon\Carbon|null $last_seen_at
 */
class StorageHost extends Model
{
    protected $table = 'storage_hosts';

    protected $guarded = ['id'];

    protected $casts = [
        'volumes' => 'array',
        'total_bytes' => 'integer',
        'free_bytes' => 'integer',
        'last_seen_at' => 'datetime',
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
