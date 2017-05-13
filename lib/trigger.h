struct zz_trigger {
  int fd;
};

void zz_trigger_poll(struct zz_trigger *t);
void zz_trigger_fire(struct zz_trigger *t);
