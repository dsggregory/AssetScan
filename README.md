# AssetScan

Watch your local network for asset changes.

**Screenshots**:

* [Dashboard](doc/Dashboard.png)
* [AssetInfo](doc/AssetInfo.png)

This uses nmap to scan **local network only** for Assets and a Rails app to manage changes.

Because this app defines an Asset's MAC as the primary key, you cannot use this
to scan networks that would be accessed behind the immediate router.

# Running

## Rails App
```
cd netscan
bin/bundle install
rails server
```
Then browse to http://localhost:3000. No data is available until you have run
your first scan.

## First Scan
Add the following to `sudo crontab -e`. Change the *-r* option to your network CIDR:
```
0 0 * * * (cd /your/path/to/netscan; rails runner bin/scan.rb -r 192.168.1.0/24 >/dev/null 2>&1)
```

So as not to wait on midnight for cron to schedule the scan, you can begin a
scan now using:
```
cd /your/path/to/netscan
rails runner bin/scan.rb -r your_network_cidr
```


