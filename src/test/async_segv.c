/* -*- Mode: C; tab-width: 8; c-basic-offset: 2; indent-tabs-mode: nil; -*- */

#include "rrutil.h"

static void handle_segv(int sig) {
  test_assert(SIGSEGV == sig);
  atomic_puts("EXIT-SUCCESS");
  exit(0);
}

int main(int argc, char* argv[]) {
  int dummy, i;

  signal(SIGSEGV, handle_segv);

  /* No syscalls after here!  (Up to the assert.) */
  for (i = 1; i < (1 << 30); ++i) {
    dummy += (dummy + i) % 9735;
  }

  /* It's possible for SEGV to be delivered too late, so succeed anyway */
  atomic_puts("EXIT-SUCCESS");
  return 0;
}
