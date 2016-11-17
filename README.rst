============================================================
Non-disrupting Ceph upgrade from 0.94.6 to 0.94.9 in MOS 9.x
============================================================

Synopsis
--------

* `Bugfixes and improvements`_
* `Preparations`_
* `Preflight checks`_
* `Upgrade ceph cluster`_
* `Restart VMs`_


Bugfixes and improvements
--------------------------

The most notable changes:

* librbd: possible QEMU deadlock after creating image snapshots,
  http://tracker.ceph.com/issues/14988
* osd: corruption when min_read_recency_for_promote > 1,
  http://tracker.ceph.com/issues/15171
* data corruption using RBD with caching enabled,
  http://tracker.ceph.com/issues/17545
* monitor crashes on a command without a prefix (CVE-2016-5009),
  http://tracker.ceph.com/issues/16297
* OSD reports ENOTEMPTY and crashes,
  http://tracker.ceph.com/issues/14766
* osd: Unable to bring up OSD’s after dealing with FULL cluster,
  http://tracker.ceph.com/issues/14428
* mon: implement reweight-by-utilization feature,
  http://tracker.ceph.com/issues/15054
* "no Last-Modified, Content-Size and X-Object-Manifest headers if no
  segments in DLO manifest",
  http://tracker.ceph.com/issues/15812

See the `official changelog`_ for more details.

.. _official changelog: http://docs.ceph.com/docs/hammer/release-notes/#v0-94-8-hammer


Preparations
------------

Please note that the upgrade procedure does not disrupt clients (such as VMs
using rbd images).

* Install ansible 2.2.x on the master node

  - Enable EPEL repository::

      wget -N https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
      yum install epel-release-latest-7.noarch.rpm

  - Install ``ansible`` package::

      yum install ansible

* Clone this repository (on the master node)::

    git clone https://github.com/asheplyakov/mos9-ceph-upgrade.git

* Prepare inventory file ``hosts`` which lists all monitor, OSD, and client
  nodes using the ``scripts/make_fuel_inventory.sh`` script.
  Use the ``hosts.sample`` example to check if the generated inventory file
  makes sense. Note: inventory *must* use hostnames (either short or fully
  qualified), listing just an IP address of a node won't work (and can break
  the cluster).


Preflight checks
----------------

* Check if ansible is able to communicate to the cluster::

    ansible -i hosts all -m ping

* Check if the cluster is OK, ``ceph -s`` should report ``HEALTH_OK``,
  all PGs should be active+clean, if not, you should fix any problems
  before upgrading.

* Check if `apt-get`` can access Ubuntu and MOS APT repositories
  (either directly or via a proxy) on monitor, OSD, and client nodes.

* (For QA only) In order to generate a test load (so bugs in ceph and upgrade
  scenario can be exposed) run on the master node::

    ansible-playbook -i hosts make_test_load.yml


Upgrade ceph cluster
----------------------

* On the master node run::

    ansible-playbook -i hosts site.yml


Restart VMs
-----------

Although the upgrading servers (monitors and OSDs) according to the above
instructions does not disrupt clients, it's necessary to restart qemu
processes serving VMs (and other services which use ceph) In order to apply
client libraries (``librados2.so`` and ``librbd1.so``) fixes. Note that
the VMs (and daemons) which haven't been restarted will keep using the old
(buggy) version of rbd client library (``librbd1.so``) and might hit
the `rbd cache data corruption`_ bug.

.. _rbd cache data corruption: http://tracker.ceph.com/issues/17545

