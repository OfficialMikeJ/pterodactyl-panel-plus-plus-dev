<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class () extends Migration {
    /**
     * NAS OS support for attached storage.
     *
     * nas_os records which operating system the storage runs: hexos,
     * truenas-core, truenas-scale, openmediavault, casaos, unraid,
     * ubuntu-server, windows-server, or any other os-release id.
     *
     * Windows Server storage does not run the attach agent — it is registered
     * as an SMB share instead (share_path + optional credentials, with the
     * password encrypted at rest).
     */
    public function up(): void
    {
        Schema::table('storage_hosts', function (Blueprint $table) {
            $table->string('nas_os', 64)->nullable()->after('provider');
            $table->string('share_path')->nullable()->after('ip');
            $table->string('share_username')->nullable()->after('share_path');
            $table->text('share_password')->nullable()->after('share_username');
        });
    }

    public function down(): void
    {
        Schema::table('storage_hosts', function (Blueprint $table) {
            $table->dropColumn(['nas_os', 'share_path', 'share_username', 'share_password']);
        });
    }
};
