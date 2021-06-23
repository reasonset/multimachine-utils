# mmffr (Multi-machines ffmpeg Rinda)

Convert massive videos with local cluster.

# Required

* ffmpeg
* Ruby >= 2.1

# Install

Copy `*.rb` on your PATH.

# Usage

1. Write configuration file `mmffr.yaml`
2. Change directory to Working directory
3. Create file list like `print -l *.mp4 > list` (Zsh)
4. Start `mmffr-ts.rb`
5. Write file list like `mmffr-q.rb list`
6. Run `mmffr-run.rb` as you want.

At remote host, mount target directory, change directory to there, and do `mmffr-run.rb`.

# File list format

## mmffr-q.rb

Source file name per line.

## mmffr-qc.rb

Tab separated UTF-8 CSV.

```
SourceFile Start Duration OutFilename
```

If `-` given as start time, convert from head.

If `-` given as duration, convert to tail.

# mmffr.yaml

All paramaters are required.

|Key|Value Type|Description|
|------|-------|------------------|
|`ts-addr`|String|TupleSpace server address. Normally use `0.0.0.0`|
|`ts-port`|Integer|TupleSpace server port.|
|`server-addr`|String|TupleSpace server host. You can use hostname.|
|`if-filter`|String|Glob pattern for choice NIC. e.g. `192.168.1.*`|
|`codec`|[]\<String\>|ffmpeg's "output_file_option s".|
|`outdir`|String|Output directory. You can use relative path.|
|`ext`|String|Output file's extension name without dot.|
|`source-style`|String|Title converting hint. `relive` is newer Radeon ReLive style filename `<title>_<date>-<time>[_<n>].mp4`. `coloros` is OPPO ColorOS Screen record style filename `Record_<date>-<time>_<appID>.mp4`. `raw` is no conversion except extension.|

# Resign cluster

Write hostname to `mmffr-stop` file (a hostname per line.)

`mmffr-run.rb` exits before taking next file.

# Config example

```yaml
---
ts-addr: "0.0.0.0"
ts-port: 25000
server-addr: fooserver.local
if-filter: 192.168.1.*
codec:
  - "-c:v"
  - libx265
  - "-r"
  - "60"
  - "-crf"
  - "31"
  - "-c:a"
  - "libopus"
  - "-b:a"
  - "256k"
outdir: ../Play
ext: mkv
source-style: relive
```