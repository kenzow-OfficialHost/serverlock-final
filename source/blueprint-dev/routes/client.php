<?php

use Illuminate\Support\Facades\Route;
use Pterodactyl\Http\Controllers\Extensions\Serverlock\LockController;

// Semua route ini otomatis kena prefix:
// /api/client/extensions/serverlock/...
//
// SENGAJA cuma 2 route di sini. Set password / unlock TIDAK lewat web
// sama sekali -- itu cuma bisa lewat artisan command di VPS (lihat README).

Route::get('/status/{server}', [LockController::class, 'status']);
Route::post('/verify/{server}', [LockController::class, 'verify']);
