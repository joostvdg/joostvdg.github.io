title: Some Basics About SystemD
description: Some Basics About Linux's SystemD

# SystemD

> Increasingly, Linux distributions are adopting or planning to adopt the `systemd` init system. 
This powerful suite of software can manage many aspects of your server, 
 from services to mounted devices and system states. [^1]

 
## Concepts 
 
### Unit
 
 > In `systemd`, a `unit` refers to any resource that the system knows how to operate on and manage.
  This is the primary object that the `systemd` tools know how to deal with. 
  These resources are defined using configuration files called **unit files**. [^1]
 

### Path

> A path unit defines a filesystem `path` that `systmed` can monitor for changes. 
 Another unit must exist that will be be activated when certain activity is detected at the path location. 
 Path activity is determined through `inotify events`.

My idea, you can use this for those services that should trigger on file uploads or backup dumps.
Although I wonder if the Unit's main service knows which path was triggered?
If it does, than it's easy, else you still need a "file walker".

## Example

```ini
[Unit]
Description=Timezone Helper Service
After=network.target
StartLimitIntervalSec=0

[Service]
Type=simple
Restart=always
RestartSec=3
User=joostvdg
ExecStart=/usr/bin/timezone_helper_service

[Install]
WantedBy=multi-user.target
```

## Resources

* https://www.linuxjournal.com/content/linux-filesystem-events-inotify

## References
[^1]: [Introduction to systemd from Digital Ocean](https://www.digitalocean.com/community/tutorials/understanding-systemd-units-and-unit-files)