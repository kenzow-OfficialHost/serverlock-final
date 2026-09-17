<?php

namespace Pterodactyl\Http\Controllers\Admin\Extensions\serverlock;

use Illuminate\View\View;
use Illuminate\View\Factory as ViewFactory;
use Pterodactyl\Http\Controllers\Controller;
use Pterodactyl\Services\Helpers\SoftwareVersionService;

use Pterodactyl\BlueprintFramework\Libraries\ExtensionLibrary\Admin\BlueprintAdminLibrary as BlueprintExtensionLibrary;

class serverlockExtensionController extends Controller
{
  /**
   * serverlockExtensionController constructor.
   */
  public function __construct(
    private BlueprintExtensionLibrary $blueprint,
    private SoftwareVersionService $version,
    private ViewFactory $view
  ){}
  
  /**
   * Return the extension index view.
   */
  public function index(): View
  {
    $rootPath = "/admin/extensions/serverlock";
    return $this->view->make('admin.extensions.serverlock.index', [
      'blueprint' => $this->blueprint,
      'version' => $this->version,
      'root' => $rootPath
    ]);
  }
}
