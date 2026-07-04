<?php

use Illuminate\Support\Facades\Route;
use Pterodactyl\Http\Controllers\Base;
use Pterodactyl\Http\Middleware\RequireTwoFactorAuthentication;

Route::get('/', [Base\IndexController::class, 'index'])->name('index')->fallback();
Route::get('/account', [Base\IndexController::class, 'index'])
    ->withoutMiddleware(RequireTwoFactorAuthentication::class)
    ->name('account');

Route::get('/locales/locale.json', Base\LocaleController::class)
    ->withoutMiddleware(['auth', RequireTwoFactorAuthentication::class])
    ->where('namespace', '.*');

// Touch Down Hosting storage attach agent (dev build feature). The script is
// public; the ingest endpoint authenticates via the one-time attach token.
Route::get('/storage/attach.sh', [Base\StorageAgentController::class, 'script'])
    ->withoutMiddleware(['auth.session', RequireTwoFactorAuthentication::class]);
Route::post('/api/storage/ingest', [Base\StorageAgentController::class, 'ingest'])
    ->withoutMiddleware(['auth.session', RequireTwoFactorAuthentication::class])
    ->middleware('throttle:30,1');

Route::get('/{react}', [Base\IndexController::class, 'index'])
    ->where('react', '^(?!(\/)?(api|auth|admin|daemon)).+');
