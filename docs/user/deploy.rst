Deploy a portal to production
=============================

.. contents::

.. note::

    For all commands in this section, ``$INFRA_DIR`` must point to the proper infrastructure directory you want to deploy.

Initializing infrastructure
---------------------------

If the infrastructure was never deployed before, you must initialize it. To do that, you must clone ``search.d`` and ``vhosts.d`` in ``customer-infra/prod/``:

#. Ask your system administrator to create the relevant bare repositories. Point it to the `correct section of the system administrator documentation <../sysadmin/deploy-setup.html>`__ if needed.
#. Use in ``geo-infra``:

  - ``manuel init-prod-repo search``
  - ``manuel init-prod-repo vhosts.d``

#. Generate and deploy the global search configuration: ``manuel deploy-global-search-conf``. At this point, the restart will fail on the server.


Deploying a new portal
----------------------

#. Generate the vhost for this portal: ``manuel vhost prod <portal>``
#. Deploy the vhosts on the server: ``manuel deploy-vhost``
#. Ask your system administrator to create the bare repository for the new portal. Point it to the `correct section of the system administrator documentation <../sysadmin/deploy-setup.html#deploy-of-a-new-portal>`__ if needed.
#. Initialize this repository with ``manuel init-prod-repo <portal>``
#. Build and deploy the portal: ``manuel deploy <portal>``


Deploying existing portals
--------------------------

Use ``manuel deploy PORTAL1 PORTAL2 …``.

If the vhosts require an update:

#. Generate them for the concerned portals: ``manuel vhost prod PORTAL1 PORTAL2 …``
#. Deploy them to the server: ``manuel deploy-vhost``


API
---

If the API need to be updated on production, ask your system administrator to do it. You can send the link `the relevant section of the documentation <../sysadmin/server-setup.html#api>`__.