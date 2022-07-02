# Multi Machines FFmpeg Tcp vp9

Flexisible cluster encoding with libvpx-vp9 for Game videos.

# Install and prepare

* `install.zsh <dir_on_path>`
* copy `sample/mmfft9.yaml` to `${XDG_CONFIG_HOME:-$HOME/.config}/reasonset/mmfft9.yaml` and edit it.
* Create output base directory.
* Craete source base directory.
* Create own title directory under source base directory.
* Copy `sample/dot.mmfft9.yaml` to `$title_source_dir/.mmfft9.yaml` and edit it.

# Start server

```bash
mmfft9-server.rb [--type TYPE]
```

Run `mmfft9-server.rb`.

# Enqueue

```bash
mmfft9-q.rb [--type TYPE]
```


Run `mmfft9-q.rb listfile`.
This command must be executed in the directory where the `.mmfft9.yaml` file is located.

The format of the listfile depends on the style specified, but for normal styles such as raw and ReLive, each line should be considered a file path, so that `$source_base_dir/$prefix/$filepath` is the source file path.
A quick way is to do something like `print -l videos/*.mp4 > list`.

This execution must be before the run is executed, but the listing may be added during the run execution.

# Run

```bash
mmfft9-run.rb [--type TYPE] [--limit MIN] [--request-min]
```

Run `mmfft9-run.rb`.

This command generates one worker, gets the processing candidates from the server, and encodes them by ffmpeg repeatedly. When there are no more candidates to process, the command terminates.

Parallel processing can be performed by creating multiple workers, and multi-host processing is also possible by creating workers on different hosts that request the same server.

If limit is specified, only candidates that are expected to finish within the specified time (minutes) are retrieved, estimated from the calculated processing size per second.

If request-min is specified, then, contrary to the usual case, the candidates with the smallest size are retrieved first.

# Tips

## Exit from cluster

If a file named `exit` exists in the state directory, run exits without obtaining the next candidate.