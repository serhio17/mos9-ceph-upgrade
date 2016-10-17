Upgrade failure 0.94.6 (MOS) to 0.94.9 (upstream)
=================================================

Steps to reproduce
------------------

* Ensure there's some IO: make an rbd image, map it, and run fio test
* Upgrade monitors one by one to 0.94.9 giving each monitor enough time to join the quorum
* Upgrade *one* OSD node to 0.94.9:
  - install the 0.94.9 ceph packages
  - try restaring one of the OSD on the node::
     service ceph-osd restart id=$ID


Results
-------

* New OSD won't start
* The following entries appear in the logs of other OSDs::

    2016-10-17 14:39:38.189330 7f1c63372700  0 log_channel(cluster) log [WRN] : failed to encode map e124 with expected crc
    2016-10-17 14:39:38.191801 7f1c63372700  0 log_channel(cluster) log [WRN] : failed to encode map e124 with expected crc
    2016-10-17 14:39:38.202528 7f1c63372700  0 log_channel(cluster) log [WRN] : failed to encode map e124 with expected crc

* In a couple of minutes OSDs start complaining about slow requests

