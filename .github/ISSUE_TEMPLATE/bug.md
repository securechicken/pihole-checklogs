---
name: 'Bug Report'
about: 'Something did not function as expected; you would like to help community by reporting and helping to fix it.'
title: '[BUG] Please enter a short description'
labels: 'bug'
assignees: ''

---
<!-- Everything wrote in between such markers before and after this phrase are comments, will not be displayed, and are to be replaced or can be deleted. The rest is to be let untouched, except where specified, or your report will be ugly. Use "Preview" tab just above to check how things will be displayed. -->
## Environment and Input
<!-- Write your information on the right column between the | | characters. Do not delete/modify any | character. If you need to use a | character in your writing, or code, put them between back-quotes, `like | this`. -->
|Item|Your information|
|---|---|
|**Host OS**|<!-- Put the name and version of your OS, as found in "PRETTY_NAME" line of /usr/lib/os-release on some GNU/Linux -->|
|**Pi-hole version**|<!-- Use 'pihole version' command on your Pi-hole host, and pick the first line, e.g.: Pi-hole version is v5.2.4 (Latest: v5.2.4) -->|
|**Pi-hole FTL version**|<!-- Use 'pihole version' command on your Pi-hole host, and pick the last line, e.g.: FTL version is v5.7 (Latest: v5.7) -->|
|**Bash version**|<!-- Use "env bash -c 'echo ${BASH_VERSION} && exit'" command on your Pi-hole host, and pick the last line, e.g.: 5.1.4(1)-release -->|
|**Pi-hole FTL-DB path**|<!-- Use 'grep "DBFILE" /etc/pihole/pihole-FTL.conf' command on your Pi-hole host, and put the result here, or "default" if empty -->|
|**Pi-hole dnsmasq logs path**|<!-- Use 'grep "log-facility" /etc/dnsmasq.d/01-pihole.conf' command on your pi-hole host, and put the result here, or "N/A" if empty -->|
|**Script location**|<!-- Put the full path of the pihole-checklogs.sh script, from where it is executed when you encountered a bug -->|
|**Input IOCs**|<!-- If possible and applicable, paste relevant part of the input IOCs file that triggered a bug, enclosing the full content in triple back-quotes to preserve formatting ```like this```-->|

## Bug description
### Expected function and references
<!-- Please describe how things are supposed to work from your perspective. Do not hesitate to reference documentation from this repo, or script's --help. -->
### Bug
<!-- Please describe the bug you identified, i.e. in what ways it did not function as expected. -->
<!-- Give as much details as possible. Include commands, terminal output, and/or code lines where relevant, between back-quotes `like this` for a simple line, or between triple back-quotes for multiple lines ``` LIKE THIS ``` -->
### Steps to Reproduce
<!-- Provide set of actions/commands to reproduce this bug. Include commands, terminal output, and/or code lines to reproduce, between back-quotes `like this` if relevant -->
1.
2. ...

## Resolution paths
### Ideas
<!-- Describe any idea you may have to fix the issue, if any. Put N/A if you do not have any -->
### Possible Implementation
<!-- If you have any suggested implementation to fix the issue, including code, put it here between triple back-quotes ``` LIKE THIS ```. Put N/A if you do not have any idea -->

<!-- Thanks in advance for submitting a complete bug report -->

