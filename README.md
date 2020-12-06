# Distributed Systems Term Project - Fall 2020
Kevin Choi (kc2296), Aathira Manoj (am10245)

### Distributed Randomness
Random numbers are everywhere, e.g. generation of private keys, voting systems, games, financial services, etc. To motivate our project, imagine a randomness beacon spewing out a random number every 30 seconds (by definition). While such a beacon exists in a centralized manner, can we really trust any single point of failure (either internal or external)? What if there is a way to distribute trust among distributed nodes?

Exploring this question, we study (and build in Elixir) 3 different types of distributed randomness beacon (DRB), through which we offer alternatives to a state-of-the-art rendition called drand (led by organizations such as Cloudflare, Protocol Labs, Ethereum Foundation, etc.) and analyze effects of Byzantine scenarios.

1. [/apps/vdf](https://github.com/kc2853/distributed-randomness/tree/main/apps/vdf) -- Commit-Reveal + VDF (verifiable delay function)
2. [/apps/randrunner](https://github.com/kc2853/distributed-randomness/tree/main/apps/randrunner) -- [RandRunner](https://eprint.iacr.org/2020/942.pdf)
3. [/apps/dvrf](https://github.com/kc2853/distributed-randomness/tree/main/apps/dvrf) -- Generalization of threshold signature via DVRF (distributed verifiable random function)