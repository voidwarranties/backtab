# Backtab

This is the backend service for [tab-ui](https://github.com/0x20/tab-ui). The current recommended way to run this is Docker.

## Running on Docker

Build the docker image using

    docker build -t backtab .

Then, create the docker VM using:

    docker create \
        -v backtab:/srv/backtab \
        -p 4903:4903 \
        -e TAB_DATA_REPO=git@github.com:0x20/tab-data \
        -e TEST_MODE=1 \
        --name backtab \
        --init \
        backtab:latest

You'll almost certainly want to change the repo name, and for production
use, you'll want to remove the TEST_MODE environment variable.

Once the container is created, you'll need to copy in an SSH private key
that has push access to the remote repo. (For test mode, you can use HTTP
and skip this step, or you can simply use an SSH key that only has read
access):

    docker cp /path/to/id_rsa backtab:/root/.ssh/

Finally, you can start the backend:

    docker start backtab

## Running natively (on NixOS)

With the flake in this repository you can deploy Backtab on NixOS. Use an overlay to make the `backtab` package
available to your configuration and import the `backtab` module exposed in `.#nixosModules`.
For example:

```nix
{
  description = "Nix flake for my infrastructure";

  inputs = {
    nixpkgs = {
      url = "github:nixos/nixpkgs/nixos-24.11";
    };

    backtab = {
      url = "github:voidwarranties/backtab";
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };
  };

  outputs = { self, nixpkgs, backtab }@inputs: {
    nixosConfigurations.myhostname = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ({ pkgs, ... }: {
          nixpkgs.overlays = [ inputs.backtab.overlays.default ];
        })
        inputs.backtab.nixosModules.backtab
        ./configuration.nix
      ];
    };
  };
}
```

Now that you have the module available, configuration is straightforward. See example `configuration.nix`:

```nix
{ pkgs, lib, config, ... }:

{
  services.backtab = {
    enable = true;

    # Point the URL below to the repository where the tab ledger is kept
    repositoryUrl = "git@github.com:example/tab-data.git";

    # Keys listed below allow users with the accompanying private key to log in as the backtab user via ssh
    # (provided openssh is enabled of course). This can be used to run `ssh-keygen` as the backtab user to generate a
    # public/private keypair to add as a (write enabled) deploy key to the tab ledger repository.
    authorizedKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILes7WTtBxDp1ILq+9iF1v2mmiQ0yFPprMREPUO240mu user@example.com"
    ];
  };
}
```

## Running natively (on Debian) (deprecated)

_This method is deprecated and the documentation is kept for historical purposes_

Build a package using

    dpkg-buildpackage --no-sign

Then, install it using

    sudo dpkg -i ../backtab_1.1_all.deb

The systemd init script will likely fail to start if you configured
backtab to use a ssh:// url; if so, add your SSH private key to
`/var/lib/backtab/.ssh` and then backtab should start.

## Running natively

Check out a copy of your data repository wherever you find convenient.
We'll call that location `/srv/backtab/tab-data`.

Next, you'll need to create a virtualenv and install backtab:

    python3 -mvenv /path/to/backtab.venv
    . /path/to/backtab.venv/bin/activate
    pip install .

Next, copy config.yml to somewhere convenient; in production I usually call
it `backtab.yml`. Edit it to your taste.

Finally, create a systemd unit for backtab:

    [Unit]
    Description=Tab backend
    Wants=network.target
    After=network.target

    [Service]
    User=hsg
    Type=notify
    NotifyAccess=main
    ExecStart=/path/to/backtab.venv/bin/backtab-server -c /path/to/backtab.yml
    StandardOutput=journal

    [Install]
    WantedBy=multi-user.target

Finally, enable and start it:

    systemctl enable backtab.service
    systemctl start backtab.service
