2024-08-29
--------------------------

* Add `-n` option to mmfft9-q
* Support SVT-AV1 with `ff_options.vcodec`

2024-05-22
--------------------------

* Outdir recursive directory creation

2023-10-20
--------------------------

* Add hungup follow feature
* Add hugefile clip support
* Use own running directory for 2pass encoding

2023-09-24
--------------------------

* Power as module
* Use mmfft9-power for power calculation
* Add estimated duration for mmfft9-info

2023-08-21
--------------------------

* Add `Origin` style for Linux desktop casting.

2023-06-13
--------------------------

* Add `rClip` style for Rythem game clip.
* Add `GeneralDT` style for mixed source. File name should have YYYYMMDDHHMM or YYYYMMDDHHMMSS format join by empty or `.-_: `
* Add `XRecorder` style for XRecorder mobile screen recorder.
* Now you can interrupt FFmpeg. When interrupt, `mmff9-run` sends `die` command to server. When server receive it, server take back processing item to queue and delete worker.
