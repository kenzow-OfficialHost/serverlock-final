<?php

namespace Pterodactyl\Providers\Blueprint;

use Illuminate\Support\Facades\Route;
use Pterodactyl\Http\Middleware\AdminAuthenticate;
use Pterodactyl\Http\Middleware\RequireTwoFactorAuthentication;
use Pterodactyl\Http\Middleware\Extensions\Serverlock\EnsureServerUnlocked;
use Illuminate\Foundation\Support\Providers\RouteServiceProvider as ServiceProvider;

class RouteServiceProvider extends ServiceProvider
{
    protected const FILE_PATH_REGEX = '/^\/api\/client\/servers\/([a-z0-9-]{36})\/files(\/?$|\/(.)*$)/i';

    /**
     * Define your route model bindings, pattern filters, etc.
     */
    public function boot(): void
    {
        /*
         * ServerLock: daftarin EnsureServerUnlocked ke middleware group
         * 'client-api' (dipakai persis sama grup yang dipakai route
         * /api/client/servers/{server}/** bawaan panel), jadi enforcement
         * lock jalan di SEMUA endpoint server -- console websocket token,
         * file manager, database, backup, dst -- bukan cuma di route milik
         * extension ini sendiri.
         *
         * Sengaja lewat pushMiddlewareToGroup() di sini, BUKAN bikin
         * ServiceProvider baru + daftar manual di config/app.php -- biar
         * nggak nambah satu lagi file "bersama" yang perlu di-patch installer.
         */
        Route::pushMiddlewareToGroup('client-api', EnsureServerUnlocked::class);

        $this->routes(function () {

            /*
             * Blueprint web routes
             */
            Route::middleware('blueprint')
                ->prefix('/extensions')
                ->group(base_path('routes/blueprint/web.php'));

            /*
             * Blueprint application API
             */
            Route::middleware([
                'blueprint/api',
                RequireTwoFactorAuthentication::class,
            ])->group(function () {

                Route::middleware([
                    'blueprint/application-api',
                    'throttle:api.application',
                ])
                    ->prefix('/api/application/extensions')
                    ->scopeBindings()
                    ->group(base_path('routes/blueprint/application.php'));
            });

            /*
             * Blueprint client API
             *
             * Samakan dengan API client Pterodactyl.
             * JANGAN gunakan blueprint/api di sini karena
             * blueprint/api memakai auth:sanctum secara langsung.
             */
            /*
             * ServerLock routes.
             *
             * LockGate berjalan dari panel browser yang sudah login,
             * jadi gunakan session authentication, bukan Client API key.
             */
            Route::middleware([
                'web',
                'auth.session',
                RequireTwoFactorAuthentication::class,
            ])
                ->prefix('/api/client/extensions/serverlock')
                ->group(base_path('routes/blueprint/client/serverlock.php'));

            /*
             * Blueprint client API lainnya tetap menggunakan
             * middleware Client API seperti sebelumnya.
             */
            Route::middleware([
                'api',
                RequireTwoFactorAuthentication::class,
                'client-api',
                'throttle:api.client',
            ])
                ->prefix('/api/client/extensions')
                ->scopeBindings()
                ->group(base_path('routes/blueprint/client.php'));

            /*
             * Blueprint admin routes
             */
            Route::middleware([
                'web',
                'auth.session',
                RequireTwoFactorAuthentication::class,
                AdminAuthenticate::class,
            ])
                ->prefix('/admin')
                ->group(base_path('routes/blueprint.php'));
        });
    }
}
