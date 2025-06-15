---
title: "GoAccess setup for Nginx sites"
date: "2025-06-15"
summary: "On my GoAccess setup for Nginx sites."
description: "On my GoAccess setup for Nginx sites."
toc: true 
readTime: true
autonumber: false 
tags: ["Linux", "Nginx", "logs", "metrics"]
showTags: false
---

This post is a straightforward technical description of my [GoAccess](https://goaccess.io/) setup. GoAccess is a neat tool to monitor visits to your pages without deploying
complex metrics and log parsing systems. GoAccess reports are pretty, detailed and clear. The problem is it's not a plug-and-play utility, like [Dozzle](https://dozzle.dev/)
which is a freaking great service to handle your Docker containers. GoAccess basically just provides you with reports and you have to (or have a privilege to) figure out how
to use them on your own. So here is my setup description and probably a guide to my future self willing to add more pages to be monitored.

I use Nginx to configure my web sites, so most examples assume it, but it probably should work the same with any other proxy server.

## Separate access log for each site

Add to the Nginx host config:
```nginx
server {
    access_log /var/log/nginx/access-site-name.log;
}
```

Restart Nginx:
```bash
systemctl restart nginx.service
```

## Log rotation

If the new log path is configured as above, `logrotate` will likely pick it up automatically. To check:

View the `logrotate` config and find the Nginx logs:
```bash
less /etc/logrotate.d/nginx
```

Run logrotate in debug mode to look for the log:
```bash
logrotate /etc/logrotate.conf --debug
```

Check the `logrotate` status (your site might not be listed yet):
```bash
cat /var/lib/logrotate/status
```

## Unified report viewing domain

**This step is done only once during initial setup.**

To view reports for all my sites in one place, I set up a dedicated Nginx server just for GoAccess reports. I added Basic Auth for access control.

Create a Basic Auth password file:
```bash
htpasswd -c /etc/nginx/reports.htpasswd admin
```

Nginx config:
```nginx
server {
    server_name          reports.kmiziz.xyz;
    auth_basic           "Administrator’s Area";
    auth_basic_user_file /etc/nginx/reports.htpasswd;

    location / {
        root /var/www/reports.kmiziz.xyz;
        index index.html;
        autoindex on;
    }
}
```

Enable the new site:
```bash
ln -s /etc/nginx/sites-available/reports /etc/nginx/sites-enabled/
```

Restart Nginx:
```bash
systemctl restart nginx.service
```

Enable SSL (see [this guide](https://www.digitalocean.com/community/tutorials/how-to-secure-nginx-with-let-s-encrypt-on-ubuntu-20-04)):
```bash
certbot --nginx -d reports.kmiziz.xyz
```

## Running GoAccess

I didn't manage to monitor multiple sites in parallel using `--daemonize` and realtime mode. For some reason running 2+ GoAccess processes resulted in only one of them
actually working and other silently terminating.

So I decided to generate static reports via `cron`, as suggested [here](https://www.ericjstauffer.com/blog/using-goaccess-to-monitor-multiple-websites-at-once). I adapted the
author's script slightly:

```bash
#!/bin/bash

# List of domain names
sites=(
  "muckraker"
  "myblog"
)

# Directory where Nginx logs are stored
log_dir="/var/log/nginx"

# Directory where the reports will be saved
report_dir="/var/www/reports.kmiziz.xyz/reports"

for site in "${sites[@]}"; do
  echo "Generating report for $domain..."

  # Run goaccess for each domain
  sudo bash -c "(zcat -f ${log_dir}/access-${site}.log*.gz; cat ${log_dir}/access-${site}.log*) | goaccess - -o ${report_dir}/${site}.html --log-format=COMBINED"

  echo "Report for $domain saved to ${report_dir}/${site}.html"
done

echo "All reports generated."
```

I run this script every 30 minutes. That’s frequent enough for me.
