# Changelog

## [1.1.1] - 2023-06-07
- Fixed: subdomains were not searched anymore for searches with less than 1000 domains, since 1.1.0.

## [1.1.0] - 2021-07-25
- Fixed: FQDNs/domains from input file can now be internationalized names (punnycode: xn--...);
- Changed: the script can now check more than 1000 domains at once (it will take a huge time though) - it only could search for 999 FQDNs/domains at once before (SQLite3 maximum tree depth limitation);
- Changed: FQDNs/domains from input are now searched as exact names or subdomains of these exact names only by default. Any DNS query for a hostname ending with the input name matched before, leading in some irrelevant matches, i.e. "anytoto.com" and "any.toto.com" matched for "toto.com", while now "toto.com" and "any.toto.com" still match for "toto.com", but not "anytoto.com".

## [1.0.0] - 2021-03-07
- No changes since 1.0.0-beta.1. Versioned as 1.0.0 after more than 15 days without any reported issue.
- Fixed: removed useless code from initial Pi-hole CLI PR.

## [Unreleased]
