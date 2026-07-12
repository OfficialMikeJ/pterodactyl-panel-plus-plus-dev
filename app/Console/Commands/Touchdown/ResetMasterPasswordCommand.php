<?php

namespace Pterodactyl\Console\Commands\Touchdown;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;

class ResetMasterPasswordCommand extends Command
{
    protected $signature = 'tdh:reset-master-password';

    protected $description = 'Reset the MASTER admin account password (the first root administrator). Can be run as many times as needed.';

    /**
     * Resets the master administrator's password without touching any config
     * or script files. Prompts for the new password twice; on a match the
     * password is changed and any remember-me tokens are revoked so old
     * sessions cannot linger.
     */
    public function handle(): int
    {
        $master = DB::table('users')->where('root_admin', true)->orderBy('id')->first();
        if ($master === null) {
            $this->error('No root administrator account exists on this panel.');

            return self::FAILURE;
        }

        $this->line('');
        $this->line('  Touch Down Hosting - Master Admin Password Reset');
        $this->line("  Account: {$master->username} <{$master->email}>");
        $this->line('');

        while (true) {
            $password = (string) $this->secret('type new password');
            $confirm = (string) $this->secret('Confirm password');

            if ($password === '') {
                $this->warn('Password cannot be empty, please try again.');
                continue;
            }

            if (strlen($password) < 8) {
                $this->warn('Password must be at least 8 characters, please try again.');
                continue;
            }

            if ($password !== $confirm) {
                $this->warn('Passwords do not match, please try again.');
                continue;
            }

            break;
        }

        DB::table('users')->where('id', $master->id)->update([
            'password' => Hash::make($password),
            'remember_token' => null,
        ]);

        $this->info('Password changed... Please login again.');

        return self::SUCCESS;
    }
}
