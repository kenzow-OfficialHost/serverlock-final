<?php

use Illuminate\Support\Facades\Route;
use Pterodactyl\Http\Controllers\Extensions\Serverlock\LockController;

Route::get('/status/{server}', [LockController::class, 'status']);
Route::post('/verify/{server}', [LockController::class, 'verify']);
