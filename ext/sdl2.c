#include <unistd.h>
#include <poll.h>

#include <SDL2/SDL_events.h>

struct zz_sdl2_sched_fd_poller {
  uint32_t sched_fd_pollin_event_type;
  int sched_fd;
  int exit_fd;
};

void *zz_sdl2_sched_fd_poller_thread(void *arg) {
  struct zz_sdl2_sched_fd_poller *self = (struct zz_sdl2_sched_fd_poller *) arg;
  SDL_Event sched_fd_pollin_event;
  SDL_zero(sched_fd_pollin_event);
  sched_fd_pollin_event.type = self->sched_fd_pollin_event_type;
  struct pollfd pollfds[2];
  /* sched_fd is the descriptor we shall monitor for readability */
  pollfds[0].fd = self->sched_fd;
  pollfds[0].events = POLLIN;
  /* if we can read from exit_fd, the thread should exit */
  pollfds[1].fd = self->exit_fd;
  pollfds[1].events = POLLIN;
  while (1) {
    int status = poll(pollfds, 2, -1);
    if (status <= 0) {
      fprintf(stderr, "sdl2: poll() failed: status=%d\n", status);
      exit(1);
    }
    if (pollfds[0].revents & POLLIN) {
      SDL_PushEvent(&sched_fd_pollin_event);
    }
    if (pollfds[1].revents & POLLIN) {
      /* got the exit signal, leave the loop */
      uint64_t exit_signal;
      int nbytes = read(pollfds[1].fd, &exit_signal, 8);
      if (nbytes != 8) {
        fprintf(stderr, "sdl2: read(exit_fd) failed: nbytes=%d\n", nbytes);
        exit(1);
      }
      if (exit_signal != 1) {
        fprintf(stderr, "sdl2: read(exit_fd) failed: exit_signal=%lld\n", exit_signal);
        exit(1);
      }
      break;
    }
  }
  return NULL;
}
