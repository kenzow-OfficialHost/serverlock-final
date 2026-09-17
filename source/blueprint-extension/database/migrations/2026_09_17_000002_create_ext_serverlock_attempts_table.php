<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Counter percobaan password salah per (user, server) -- dasar buat
 * lockout sementara di LockController::verify(). Independen dari
 * throttle route-level, karena throttle Laravel biasanya di-key per
 * IP/user secara global dan bisa reset kalau IP-nya ganti; tabel ini
 * spesifik per server yang dikunci jadi lebih susah dihindari.
 */
return new class extends Migration
{
    public function up()
    {
        Schema::create('ext_serverlock_attempts', function (Blueprint $table) {
            $table->id();
            $table->unsignedInteger('user_id');
            $table->string('server_uuid');
            $table->unsignedSmallInteger('attempts')->default(0);
            $table->timestamp('locked_until')->nullable();
            $table->timestamps();

            $table->unique(['user_id', 'server_uuid']);
        });
    }

    public function down()
    {
        Schema::dropIfExists('ext_serverlock_attempts');
    }
};
