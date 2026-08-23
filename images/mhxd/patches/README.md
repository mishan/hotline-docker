# Local mhxd patches

Applied on top of the pinned `MHXD_REV` by the image build, in filename
order. `git apply` is not tolerant: a patch that stops applying fails the
build rather than being skipped, so bumping `MHXD_REV` means revisiting
what is here — a silently dropped patch would ship the bug it fixes.

Send these upstream (<https://github.com/kangsterizer/mhxd>) and drop them
here once merged.

## 0001-tnews-terminate-and-bound-news-folder-names.patch

`rcv_news_mkdir` copies the client's `HTLC_DATA_FILE_NAME` into a stack
buffer and never terminates it, then uses it as a C string:

```c
memcpy(dirname, dh_data, dh_len);      /* no NUL */
...
snprintf(path, sizeof(path), "%s/%s", hxd_cfg.paths.newsdir, dirname);
```

So the created directory is the requested name plus whatever the stack
happened to hold past it. In practice the slot holds the `newsdir` config
value, which makes the symptom look almost deliberate: asking for `test`
creates `testwsdir` and asking for `ProbeB` creates `ProbeBdir` — both the
tail of `./newsdir` at the offset where the name ended. `rcv_news_mkcategory`
terminates its equivalent buffer; `rcv_news_mkdir` just missed the line.

Both functions also clamp the length *after* the copy, so a name longer than
`MAXPATHLEN` overruns the buffer before anything checks it. The patch clamps
first in both, then copies, then terminates.
