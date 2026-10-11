# Local mhxd patches

Applied on top of the pinned `MHXD_REV` by the image build, in filename
order. `git apply` is not tolerant: a patch that stops applying fails the
build rather than being skipped, so bumping `MHXD_REV` means revisiting
what is here — a silently dropped patch would ship the bug it fixes.

Send these upstream (<https://github.com/kangsterizer/mhxd>) and drop them
here once merged.

- `0001-htxf-get-thread-cleanup-scope.patch`: a download's thread jumped out
  of its `pthread_cleanup_push` scopes when a send failed or the client closed
  early, which is undefined behavior (kangsterizer/mhxd#10).
- `0002-free-htxf-unlock.patch`: `free_htxf` returned holding the connection's
  `htxf_mutex` when the slot was already empty, so the next lock hung
  (kangsterizer/mhxd#11).
