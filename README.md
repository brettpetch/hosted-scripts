# Hosted Scripts

This repo is a helper repo for Swizzin.net & HostingBy.Design appboxes. Here you will find additional scripts for installing frequently requested software that hasn't been baked into the real deal yet. Think of this as a beta of a beta. Some stuff might not work, but it's better than nothing at all. Some apps can have authentication configured by us, some can't. Some have no baseurl support, so we just run it on the port. There are no warranties for these scripts. You get whatever is here with no support guaranteed whatsoever. 

## DO NOT RUN THESE SCRIPTS ON DEDICATED SERVERS!
You should not run these scripts on servers running Swizzin Community Edition. This is meant for HostingBy.Design AppRange and Swizzin.net customers. If you DO NOT HAVE root on the server in question, you may consider using these. If you DO HAVE ROOT, please just yell in one of the Swizzin / HostingBy.Design support channels until I show up.

This script makes major modifications to how node is installed for some applications. It can break apps that are run in userland that require node. 

## Install
If you actually want all this stuff, you can grab the repository by doing 

### The Whole Enchilada
```bash
mkdir -p $HOME/scripts/
git clone https://github.com/brettpetch/hosted-scripts.git $HOME/scripts/hosted-scripts
```

### Just a Slice
```bash
bash <(curl -sL "https://github.com/brettpetch/hosted-scripts/raw/master/scriptname.sh")
```

## Updates

```bash
git -C $HOME/scripts/hosted-scripts pull
```

## Development
Do you think you can do it better? Go nuts. PRs are welcome. Please ensure your permissions are set to 755 on commit.

## Support
These scripts **come with no support**. If you have questions, feel free to ask them in their respective discords (dependant on vendor). Remember to respect the rules of the vendors in their discords and be respectful to community members lending their assistance.

### For Swizzin.net Customers: 

[Discord](https://discord.gg/2esbu2N)

[Documentation](https://docs.swizzin.net)

[Affiliate Link](https://clients.swizzin.net/aff.php?aff=33)

### For HostingBy.Design Customers: 

[Discord](https://discord.gg/wv67teS)

[Documentation](https://docs.hostingby.design/)

[Affiliate Link](https://my.hostingby.design/aff.php?aff=1119)



## Security Disclosures

### September 2, 2025

**Summary**  
Before September 2, 2025, the Tailscale setup script did not correctly bind to network interfaces. This misconfiguration could expose `tailscaled` as an open SOCKS5 proxy, potentially allowing unauthorized access and causing affected systems to be blacklisted.

---

#### Timeline
- **2025-07-22, 03:05 AM (UTC)** — HBD staff raised the first alarm after reports of systems being blacklisted by DroneBL.  
- **Subsequent investigation** — Scans confirmed that when the Tailscale port was discovered, it responded as an open proxy, triggering DroneBL blocks.  
- **Root cause identified** — The script failed to ensure that the `$subnet` variable was correctly populated before writing to the user’s `tailscaled.service` file at:  

  ```bash
  $HOME/.config/systemd/user/tailscaled.service
  ```

#### Technical Details
The script attempted to set interface binding using:

  ```bash
  --outbound-http-proxy-listen=${subnet}:${proxy_port} --socks5-server=${subnet}:${socks5_port}
  ```

However, because `${subnet}` was empty, the resulting systemd unit contained lines such as:

  ```bash
  .tmp/tailscale/tailscaled.sock --outbound-http-proxy-listen=:10978 --socks5-server=:8001
  ```

This effectively bound the proxy services to all interfaces, leaving them accessible from the public internet.

The underlying cause was a typo in the script:
```
cat .subnet.lock
```
should have been:
```
cat subnet.lock
```

As a result, no subnet value was populated, and defaults were applied incorrectly.

#### Impact

- Systems ran tailscaled as an open SOCKS5 proxy.
- Affected systems risked network intrusion and were subject to blacklisting by DroneBL and other services.

#### Mitigation

- HBD staff pushed an emergency update to disable the Tailscale daemon for all affected users.
- Affected users were notified by email with instructions to uninstall or apply the mitigation.
- The script has since been corrected to enforce proper subnet binding.

#### Acknowledgements

We sincerely apologize for any disruption or security risk this issue may have caused.
We would like to thank the HBD team for promptly raising the alarm and working with us to address the vulnerability.
