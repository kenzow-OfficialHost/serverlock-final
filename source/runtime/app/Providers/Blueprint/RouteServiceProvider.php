<?php

namespace Pterodactyl\Providers\Blueprint;

use Illuminate\Support\Facades\Route;
use Pterodactyl\Http\Middleware\AdminAuthenticate;
use Pterodactyl\Http\Middleware\RequireTwoFactorAuthentication;
use Illuminate\Foundation\Support\Providers\RouteServiceProvider as ServiceProvider;

class RouteServiceProvider extends ServiceProvider
{
    protected const FILE_PATH_REGEX = '/^\/api\/client\/servers\/([a-z0-9-]{36})\/files(\/?$|\/(.)*$)/i';

    /**
     * Define your route model bindings, pattern filters, etc.
     */
    public function boot(): void
    {
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
