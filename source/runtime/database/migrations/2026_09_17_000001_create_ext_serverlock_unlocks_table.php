<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * "Grant" sementara yang dikeluarkan tiap kali user berhasil masukin
 * password yang benar di LockGate. Ini yang dibaca middleware
 * EnsureServerUnlocked buat nentuin boleh/nggaknya request ke server
 * yang lagi dikunci -- BUKAN cuma state React di frontend.
 */
return new class extends Migration
{
    public function up()
    {
        Schema::create('ext_serverlock_unlocks', function (Blueprint $table) {
            $table->id();
            $table->unsignedInteger('user_id');
            $table->string('server_uuid');
            $table->timestamp('expires_at');
            $table->timestamps();

            $table->unique(['user_id', 'server_uuid']);
            $table->index('expires_at');
        });
    }

    public function down()
    {
        Schema::dropIfExists('ext_serverlock_unlocks');
    }
};
