<?php

use Illuminate\Support\Facades\Route;
use Pterodactyl\Http\Controllers\Extensions\Serverlock\LockController;

Route::get('/status/{server}', [LockController::class, 'status']);

// throttle:8,1 -> maksimal 8 request/menit per user (Laravel default key:
// user id kalau login, IP kalau nggak). Lapisan pertama; lapisan kedua
// (lebih ketat & spesifik per-server) ada di ext_serverlock_attempts,
// lihat LockController::verify().
Route::post('/verify/{server}', [LockController::class, 'verify'])->middleware('throttle:8,1');
