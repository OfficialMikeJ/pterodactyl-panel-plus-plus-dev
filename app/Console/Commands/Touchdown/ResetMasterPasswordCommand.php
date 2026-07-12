<?php

namespace Pterodactyl\Console\Commands\Touchdown;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;

class ResetMasterPasswordCommand extends Command
{
    public const MIN_LENGTH = 12;
    public const MAX_LENGTH = 64;
    public const REQUIREMENTS = '12-64 characters with at least one lowercase letter, one uppercase letter, one number and one special character.';

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
        $this->line('  Password requirements: ' . self::REQUIREMENTS);
        $this->line('');

        while (true) {
            $password = (string) $this->secret('type new password');

            $problems = $this->validatePassword($password);
            if (Hash::check($password, $master->password)) {
                $problems[] = 'The new password cannot be the same as the current password.';
            }

            if (!empty($problems)) {
                foreach ($problems as $problem) {
                    $this->warn($problem);
                }
                $this->warn('Please try again.');
                continue;
            }

            $confirm = (string) $this->secret('Confirm password');
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

    /**
     * @return string[] every policy rule the candidate password violates
     */
    private function validatePassword(string $password): array
    {
        $problems = [];
        $length = strlen($password);

        if ($length < self::MIN_LENGTH || $length > self::MAX_LENGTH) {
            $problems[] = sprintf('Password must be between %d and %d characters.', self::MIN_LENGTH, self::MAX_LENGTH);
        }

        if (!preg_match('/[a-z]/', $password)) {
            $problems[] = 'Password must contain at least one lowercase letter.';
        }

        if (!preg_match('/[A-Z]/', $password)) {
            $problems[] = 'Password must contain at least one uppercase letter.';
        }

        if (!preg_match('/[0-9]/', $password)) {
            $problems[] = 'Password must contain at least one number.';
        }

        if (!preg_match('/[^a-zA-Z0-9]/', $password)) {
            $problems[] = 'Password must contain at least one special character (e.g. !@#$%).';
        }

        return $problems;
    }
}
