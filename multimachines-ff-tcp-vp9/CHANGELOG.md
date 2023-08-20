2023-08-21
--------------------------

* Add `Origin` style for Linux desktop casting.

2023-06-13
--------------------------

* Add `rClip` style for Rythem game clip.
* Add `GeneralDT` style for mixed source. File name should have YYYYMMDDHHMM or YYYYMMDDHHMMSS format join by empty or `.-_: `
* Add `XRecorder` style for XRecorder mobile screen recorder.
* Now you can interrupt FFmpeg. When interrupt, `mmff9-run` sends `die` command to server. When server receive it, server take back processing item to queue and delete worker.