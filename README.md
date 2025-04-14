# Create a Tor network hidden service with a vanity .onion address with Docker

* * *

## Using Tor to host an .onion service

The purpose of this repo is to give someone a chance to test out hosting an .onion hidden service.

You can use this to quickly share a service to a friend, client, or even your future self.

> A Tor hidden service does not need your server to have open ports or port forwarding - because it does not accept direct inbound connections from the public internet. Instead, both the client and the hidden service connect outbound to the Tor network, establishing circuits to special relays called introduction and rendezvous points. All communication is routed through these Tor relays, so as long as your server can make outbound connections to the Tor network, it can host a hidden service!



* * *

## 1-up-tor-onion-address script

[This script](https://github.com/MarcusHoltz/tor-hidden-service/blob/main/1-up-tor-onion-address.sh) sets up **one** service that will be available through a [Tor .onion address](https://en.wikipedia.org/wiki/.onion).

> This service is only available through the Tor network
{: .prompt-info }

This is intended as a demonstration. I hope you're able to learn and enjoy using. If you'd like more information head over to the [Holtzweb Blog post](https://blog.holtzweb.com/posts/tor-network-hidden-service-vanity-website-setup-with-docker/).

- [1-up-tor-onion-address.sh](https://raw.githubusercontent.com/MarcusHoltz/tor-hidden-service/refs/heads/main/1-up-tor-onion-address.sh)

```bash

wget https://github.com/MarcusHoltz/tor-hidden-service/archive/refs/heads/main.zip -O tor-hidden-service-repo.zip && unzip tor-hidden-service-repo.zip && cd tor-hidden-service-main

```

![1-up Tor Onion Address Script for a Tor Hidden Service](https://raw.githubusercontent.com/MarcusHoltz/marcusholtz.github.io/refs/heads/main/assets/img/posts/1-up-tor-script-hidden-onion-service.gif)

* * *

### Script Requirements

This script will need sudo. It is required to set all of the directory permissions correctly. 

You will then need docker installed to generate a vanity address and run the `docker-compose.yml` file that starts up Tor.

The script is only intended to prepare the environment we're using with Docker.



* * *

### Changes the Script makes

The script sets up two directories, a file, and optionally a vanity address.


#### Two Directories

You need the sudo for privs for:

- tor_config/vanity_keys/

and

- tor_data/

> Those directories store the keys that are used for your .onion address. Kept safe from any normal user.



#### A file: torrc

The [torrc file](https://support.torproject.org/glossary/torrc/) contains all the settings Tor uses. 

You need the sudo for privs for:

- tor_config/torrc

> By changing this file we can tell Tor what services we want to serve on a Tor Hidden Service and where to find the corresponding .onion address.


* * *

## Vanity Name Creation

A [vanity address](https://community.torproject.org/onion-services/advanced/vanity-addresses/) is an onion address that starts with a pre-chosen number of characters, usually a meaningful name related to a specific Onion Service. 

For instance, one might try to generate an onion address for the mysitename website and end up with something looking like this:

`mysitenameyx4fi3l6x2gyzmtmgxjyqyorj9qsb5r543izcwymle.onion`

This has some advantages:

- It is easy for Onion Services users to know which site they are about to access.

- It has some branding appeal to site owners.

- It is easy for Onion Services operators to debug their logs and know which services have errors.

- Anyone else is very unlikely to come up with the exact key from the example above, but they may be able to find a similar key - one beginng with the same few letters. 

  - The longer the vanity name length, the less likly it is to have a forgery made.


* * *

### Vanity Name Length

You can only pick something, at max, 7 characters.

> Why?

Let's say you were running this on a Raspberry Pi 2B....

Take a look at the approximate generation time per character for a Raspberry Pi 2B below:

#### Approximate Generation Time per Character Count Chart

```text
Vanity Characters : Approximate Generation Time
1  : <1 second
2  : <1 second
3  : 1 second
4  : 30 seconds
5  : 16 minutes
6  : 8.5 hours
7  : 11.5 days
8  : 1 year
9  : 32 years
10 : 1,024 years
11 : 32,768 years
12 : 1 million years
```



* * *

### Example vanities

So now that we know our upper limit on the amount of letters we can have, take a look at some examples....

Click to expand and take a look at the 6 character example vanities below:

<details>

<summary>6 character example vanity .onion domains</summary>  

- 123456

- nopers

- online

- system

- search

- office

- forums

- mobile

- garden

- nature

- movies

- photos

- social

- future

- people

- estate

- energy

- income

- browse

- create

- report

- global

- agency

- potato

- attack

- wisdom

- stream

- viewer

- status

- screen

- sector

- survey

- secure

- signal

- source

- remote

- direct

- little

- jazzed

- dazzle

- danger

- school

- family
</details>


* * *

### How is the vanity generated

Thanks to the work on the [cathugger/mkp224o](https://github.com/cathugger/mkp224o) repository, we're able to generate vanity address for tor onion v3 (ed25519) hidden services.

- Specifically, the script will run: `docker run ghcr.io/cathugger/mkp224o:master -n 3 <your_vanity_name>`

- It will generate `3` .onion addresses that begin with your vanity name, allowing you to select a favorite.

- The .onion address will be in `tor_config/vanity_keys/`


### Can't I just use my own .onion address

Yes! This script will prompt you to use your own, you just have to provide the path.


#### Instructions for Using Bringing Your Own Vanity Tor Address:

1. Make sure you have all of your files for your .onion address in the same directory:

   - `hostname` - Contains your .onion address

   - `hs_ed25519_secret_key` - Your private key

   - `hs_ed25519_public_key` - Your public key


2. After the script completes, verify your hidden service is correct:

```bash

sudo cat tor_data/hidden_service/hostname

```


* * *

## What Service to put on Tor

You will also need a service to provide to the .onion address. 

This can be anything. It can be another docker container, a python web server on your laptop, your favorite IoT device, whatever!

You will just need to give the script:

- The IP or Hostname of the service you're sending to the Tor network.

- The port for the service to forward over the .onion address.

- ONLY ONE SERVICE!!!    --> tor_data/hidden_service/

> This script is designed for demonstration and as such, there's only one service designed into the script. You can always make multiple services on the same .onion address with different ports, or a new .onion address for every service. But today, only one service.


* * *

## Torrc is important

The `torrc` file lets you define `HiddenServiceDir` and `HiddenServicePort` directives, these tell Tor where to store your service you're sending to the Tor network's keys and what ports to forward, making your .onion site accessible.


* * *

## The 1-up Tor Script uses two directories

File permissions are critical for Tor hidden services:
   - Directories need 700 permissions (drwx------)
   - Key files need 600 permissions (-rw-------)
   - The docker container will adjusts these permissions for you

The Tor user (not root) must own all these files inside the container


* * *

## Browsers that find an onion service

- Use [Brave Browser](https://support.brave.com/hc/en-us/articles/360018121491-What-is-a-Private-Window-with-Tor-Connectivity)

- Use [Tor Browser](https://support.torproject.org/)



* * *

## Want to know more?

Want to know more about this script? How about a breakdown of the script's logic!

* * *

### Take a look at the flow of the script

<details>

<summary>Visual Script Breakdown</summary>  

```text

┌───────────────────────┐
│    check_sudo()       │
│  - Verify privileges  │
└──────────┬────────────┘
           ▼
┌───────────────────────┐
│ create_directories()  │
│  - tor_config/        │
│  - tor_data/          │
└──────────┬────────────┘
           ▼
┌───────────────────────┐
│  set_permissions()    │
│  - 755 config         │
│  - 700 data           │
└──────────┬────────────┘
           ▼
┌───────────────────────┐
│get_network_settings() │
│  - Collect:           │
│    • HOST_IP          │
│    • HOST_PORT        │
│    • VIRTUAL_PORT     │
└──────────┬────────────┘
           ▼
┌───────────────────────┐
│setup_vanity_address() │
└──────────┬────────────┘
           ├────────────────────────────┐
           ▼                            ▼
┌───────────────────────┐      ┌───────────────────────┐
│  Generate New Address │      │  Use Existing Keys    │
│  - mkp224o Docker     │      │  - Validate dir       │
│  - vanity name input  │      │  - Verify key files   │
└──────────┬────────────┘      └──────────┬────────────┘
           ▼                              ▼
┌───────────────────────┐      ┌───────────────────────┐
│  Select From Generated│      │ Copy Existing Keys    │
│  - Display options    │      │  - hostname           │
│  - Validate selection │      │  - secret_key         │
└──────────┬────────────┘      └──────────┬────────────┘
           └────────────┬─────────────────┘
                        ▼
┌─────────────────────────────────────────┐
│      setup_hidden_service_dir()         │
│  - Create hidden_service/               │
│  - Set 700 permissions                  │
└──────────┬──────────────────────────────┘
           ▼
┌───────────────────────┐
│   create_torrc()      │
│  - HiddenServicePort  │
│  - DataDirectory      │
└──────────┬────────────┘
           ▼
┌───────────────────────┐
│  finalize_setup()     │
│  - Set file perms     │
│  - Display hostname   │
│  - Run instructions   │
└───────────────────────┘

```
</details>

