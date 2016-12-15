# AssetScan

Watch your local network for asset changes.

This usees nmap to scan **local network only** for Assets and a Rails app to manage changes.

Because this app defines an Asset's MAC as the primary key, you cannot use this
to scan networks that would be accessed behind the immediate router.