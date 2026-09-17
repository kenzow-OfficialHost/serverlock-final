<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up()
    {
        Schema::create('ext_serverlock_locks', function (Blueprint $table) {
            $table->id();
            // UUID server Pterodactyl (bukan uuidShort), unik per server.
            $table->string('server_uuid')->unique();
            $table->string('password_hash');
            $table->boolean('enabled')->default(true);
            $table->timestamps();
        });
    }

    public function down()
    {
        Schema::dropIfExists('ext_serverlock_locks');
    }
};
