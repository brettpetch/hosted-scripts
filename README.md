# Hosted Scripts

This repo is a helper repo for Swizzin.net & SBIO Seedboxes. Here you will find additional scripts for installing frequently requested software that hasn't been baked into the real deal yet. Think of this as a beta of a beta. Some stuff might not work, but it's better than nothing at all. Some apps can have authentication configured by us, some can't. Some have no baseurl support, so we just run it on the port. There are no warranties for these scripts. You get whatever is here with no support guaranteed whatsoever. 

## DO NOT RUN THESE SCRIPTS ON DEDICATED SERVERS!
You should not run these scripts on servers running Swizzin Community Edition. This is meant for seedbox.io apprange and swizzin.net customers. If you DO NOT HAVE root on the server in question, you may consider using these. If you DO HAVE ROOT, please just yell in one of the swizzin support channels until I show up.

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

### For SBIO Customers: 

[Discord](https://discord.gg/wv67teS)

[Documentation](https://docs.seedbox.io)
