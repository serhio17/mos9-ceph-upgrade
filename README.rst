=====================================================================
Non-disrupting Ceph upgrade from Firefly (0.80.10) to Hammer (0.94.9)
=====================================================================

Synopsis
--------

* `Preparations`_
* `Preflight checks`_
* `Upgrade ceph cluster`_
* `Restart VMs`_


Preparations
------------

Please note that the upgrade procedure does not disrupt clients (such as VMs
using rbd images).

* Install ansible 2.2.x on the master node, see `ansible official docs`_
  for the details

.. _ansible official docs: http://docs.ansible.com/ansible/intro_installation.html#installing-the-control-machine

* Clone this repository (on the master node)::

    git clone https://github.com/asheplyakov/mos9-ceph-upgrade.git
    git checkout -b firefly_hammer origin/firefly_hammer

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

