<?php

namespace Pterodactyl\Listeners;

use Pterodactyl\Models\User;
use Pterodactyl\Events\ActivityLogged;
use Pterodactyl\Services\Touchdown\TrophyService;
use Pterodactyl\Services\Touchdown\TrophyQualifiers;

class TrophyListener
{
    public function __construct(private TrophyService $service)
    {
    }

    /**
     * Every activity log entry the panel writes flows through here; if the actor
     * is a user, the Touch Down Hosting trophy system gets a chance to award.
     * Trophies must never break the underlying request, so failures (including
     * running before the trophy migration has been applied) are swallowed.
     */
    public function handle(ActivityLogged $event): void
    {
        $actor = $event->model->actor;
        if (!$actor instanceof User) {
            return;
        }

        try {
            // A single activity can advance several counters: the plain event
            // plus more specific ones (e.g. "server:delete:rust").
            $events = array_merge(
                [$event->model->event],
                TrophyQualifiers::for($event->model->event, $event->model->properties),
            );

            foreach ($events as $name) {
                $this->service->handleEvent($actor, $name);
            }
        } catch (\Throwable $exception) {
            logger()->warning('Touch Down Hosting trophy system failed to process an event.', [
                'event' => $event->model->event,
                'exception' => $exception->getMessage(),
            ]);
        }
    }
}
