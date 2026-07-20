<?php

namespace Pterodactyl\Http\Controllers\Base;

use Illuminate\Contracts\View\View;
use Pterodactyl\Http\Controllers\Controller;

/**
 * Touch Down Hosting — public Terms of Service / Terms of Use page. The
 * content lives in resources/views/templates/terms.blade.php and is edited
 * externally, the same policy as the Dev-Blogs.
 */
class TermsController extends Controller
{
    public function __invoke(): View
    {
        return view('templates.terms');
    }
}
