# Local mhxd patches

Applied on top of the pinned `MHXD_REV` by the image build, in filename
order. `git apply` is not tolerant: a patch that stops applying fails the
build rather than being skipped, so bumping `MHXD_REV` means revisiting
what is here — a silently dropped patch would ship the bug it fixes.

Send these upstream (<https://github.com/kangsterizer/mhxd>) and drop them
here once merged.

- `0001-resolve-without-a-thread-per-login.patch`: resolve a client's address
  on the main thread instead of a thread per login, which has crashed hxd in
  glibc's thread stack cache.
