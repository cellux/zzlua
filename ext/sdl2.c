#include <unistd.h>
#include <sys/epoll.h>

#include <SDL2/SDL_events.h>

#include "trigger.h"

struct zz_sdl2_sched_fd_poller {
  uint32_t sched_fd_pollin_event_type;
  int sched_fd;
  zz_trigger poll_trigger;
  zz_trigger exit_trigger;
};

void *zz_sdl2_sched_fd_poller_thread(void *arg) {
  struct zz_sdl2_sched_fd_poller *self = (struct zz_sdl2_sched_fd_poller *) arg;
  SDL_Event sched_fd_pollin_event;
  SDL_zero(sched_fd_pollin_event);
  sched_fd_pollin_event.type = self->sched_fd_pollin_event_type;
  int epfd = epoll_create(1);
  if (epfd < 0) {
    fprintf(stderr, "sdl2_sched_fd_poller: epoll_create() failed\n");
    exit(1);
  }
  struct epoll_event ev;
  memset(&ev, 0, sizeof(ev));
  ev.data.fd = self->sched_fd;
  ev.events = EPOLLIN | EPOLLONESHOT;
  if (epoll_ctl(epfd, EPOLL_CTL_ADD, self->sched_fd, &ev) != 0) {
    fprintf(stderr, "sdl2_sched_fd_poller: epoll_ctl(ADD) failed (sched_fd)\n");
    exit(1);
  }
  ev.data.fd = self->poll_trigger.fd;
  ev.events = EPOLLIN;
  if (epoll_ctl(epfd, EPOLL_CTL_ADD, self->poll_trigger.fd, &ev) != 0) {
    fprintf(stderr, "sdl2_sched_fd_poller: epoll_ctl(ADD) failed (poll_trigger.fd)\n");
    exit(1);
  }
  ev.data.fd = self->exit_trigger.fd;
  ev.events = EPOLLIN;
  if (epoll_ctl(epfd, EPOLL_CTL_ADD, self->exit_trigger.fd, &ev) != 0) {
    fprintf(stderr, "sdl2_sched_fd_poller: epoll_ctl(ADD) failed (exit_trigger.fd)\n");
    exit(1);
  }
  while (1) {
    int status = epoll_wait(epfd, &ev, 1, -1);
    if (status <= 0) {
      fprintf(stderr, "sdl2_sched_fd_poller: epoll_wait() failed: status=%d\n", status);
      exit(1);
    }
    if (ev.data.fd == self->sched_fd && (ev.events & EPOLLIN)) {
      SDL_PushEvent(&sched_fd_pollin_event);
    }
    else if (ev.data.fd == self->poll_trigger.fd && (ev.events & EPOLLIN)) {
      zz_trigger_poll(&self->poll_trigger);
      ev.data.fd = self->sched_fd;
      ev.events = EPOLLIN | EPOLLONESHOT;
      if (epoll_ctl(epfd, EPOLL_CTL_MOD, self->sched_fd, &ev) != 0) {
        fprintf(stderr, "sdl2_sched_fd_poller: epoll_ctl(MOD) failed (sched_fd)\n");
        exit(1);
      }
    }
    else if (ev.data.fd == self->exit_trigger.fd) {
      zz_trigger_poll(&self->exit_trigger); /* ack */
      break;
    }
    else {
      fprintf(stderr, "sdl2_sched_fd_poller: invalid fd in epoll_event structure: %d\n", ev.data.fd);
      exit(1);
    }
  }
  close(epfd);
  return NULL;
}
