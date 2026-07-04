<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class () extends Migration {
    /**
     * Touch Down Hosting — attached storage (dev build feature). Each row is a
     * host registered through the one-command SSH attach agent, whether that is
     * extra disks on a local machine, a dedicated storage server, or cloud
     * block-storage volumes (Linode, Hetzner, OVH, DigitalOcean, ...).
     */
    public function up(): void
    {
        Schema::create('storage_hosts', function (Blueprint $table) {
            $table->id();
            $table->unsignedInteger('user_id');
            $table->string('name');
            $table->string('token_hash', 64)->unique();
            $table->string('status')->default('pending'); // pending | attached
            $table->string('mode')->nullable();           // local-device | storage-server
            $table->string('provider')->nullable();       // linode | hetzner | ovh | digitalocean | local | unknown
            $table->string('hostname')->nullable();
            $table->string('ip')->nullable();
            $table->unsignedBigInteger('total_bytes')->nullable();
            $table->unsignedBigInteger('free_bytes')->nullable();
            $table->json('volumes')->nullable();
            $table->timestamp('last_seen_at')->nullable();
            $table->timestamps();

            $table->foreign('user_id')->references('id')->on('users')->cascadeOnDelete();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('storage_hosts');
    }
};
