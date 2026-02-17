![Dojo Starter](./assets/cover.png)

<picture>
  <source media="(prefers-color-scheme: dark)" srcset=".github/mark-dark.svg">
  <img alt="Dojo logo" align="right" width="120" src=".github/mark-light.svg">
</picture>

<a href="https://x.com/ohayo_dojo">
<img src="https://img.shields.io/twitter/follow/dojostarknet?style=social"/>
</a>
<a href="https://github.com/dojoengine/dojo/stargazers">
<img src="https://img.shields.io/github/stars/dojoengine/dojo?style=social"/>
</a>

[![discord](https://img.shields.io/badge/join-dojo-green?logo=discord&logoColor=white)](https://discord.com/invite/dojoengine)
[![Telegram Chat][tg-badge]][tg-url]

[tg-badge]: https://img.shields.io/endpoint?color=neon&logo=telegram&label=chat&style=flat-square&url=https%3A%2F%2Ftg.sumanjay.workers.dev%2Fdojoengine
[tg-url]: https://t.me/dojoengine

# Dojo Starter: Official Guide

A quickstart guide to help you build and deploy your first Dojo provable game.

Read the full tutorial [here](https://dojoengine.org/tutorial/dojo-starter).

## Deterministic Generation Ops

World generation is now deterministic and config-driven through `WorldGenConfig` (active key: `generation_version=1`).

- `scarb run migrate` now performs:
1. `sozo build`
2. `sozo migrate`
3. `init-world-gen` one-time active config initialization

Manual init (if needed):

```bash
sozo execute dojo_starter-world_gen_manager initialize_active_world_gen_config \
  0x574f524c445f47454e5f534545445f5631 2200 2200 2200 3 3 3 --wait
```

Verify active config:

```bash
sozo model get dojo_starter-WorldGenConfig 1
```

Run focused smoke coverage:

```bash
scarb run smoke
```

## Running Locally

#### Terminal one (Make sure this is running)

```bash
# Run Katana
katana --dev --dev.no-fee
```

#### Terminal two

```bash
# Build the example
sozo build

# Inspect the world
sozo inspect

# Migrate the example
sozo migrate

# Start Torii
# Replace <WORLD_ADDRESS> with the address of the deployed world from the previous step
torii --world <WORLD_ADDRESS> --http.cors_origins "*"
```

## Explorer UI Usage (Bun)

The explorer dev harness lives in the sibling `client/` workspace and runs with Bun.

### Start locally

```bash
cd ../client
bun install
bun run dev:app
```

Open:
- Live mode (default): `http://127.0.0.1:4173`
- Mock mode: `http://127.0.0.1:4173/?source=mock`
- Live mode with explicit Torii endpoint:
  `http://127.0.0.1:4173/?torii=https://api.cartridge.gg/x/<slot>/torii/graphql`

### Using the UI

- `Navigation`: pan/zoom and mobile/desktop viewport presets.
- `Layers`: toggle biome/ownership/claims/adventurers/resources/decay overlays.
- `Search + Deep Link`: jump by `coord`, `owner`, or `adventurer`; hydrate from URL.
- `Stream Status`: simulate `live`, `catching_up`, and `degraded` states.
- `Inspect`: click a discovered hex to view structured details (hex, areas, ownership, decay, claims, plants, reservations, adventurers, economics, inventory, construction, deaths, events).

Note: current live runtime updates are GraphQL polling (heartbeat-style), not a direct websocket stream.

## Explorer UI Deployment

Build the static app bundle:

```bash
cd ../client
bun install
bun run --filter @gen-dungeon/explorer-app build
```

Build output:
- `../client/packages/explorer-app/dist`

Smoke check the built bundle locally:

```bash
cd ../client
bun run --filter @gen-dungeon/explorer-app preview
```

Deploy `../client/packages/explorer-app/dist` to any static host (Vercel/Netlify/S3+CloudFront/Nginx).  
After deploy, pass your production Torii GraphQL endpoint with the `torii` query param, for example:

`https://<your-ui-domain>/?torii=https://api.cartridge.gg/x/<slot>/torii/graphql`

## Docker
You can start stack using docker compose. [Here are the installation instruction](https://docs.docker.com/engine/install/)

```bash
docker compose up
```
You'll get all services logs in the same terminal instance. Whenever you want to stop just ctrl+c

---

## Contribution

1. **Report a Bug**

    - If you think you have encountered a bug, and we should know about it, feel free to report it [here](https://github.com/dojoengine/dojo-starter/issues) and we will take care of it.

2. **Request a Feature**

    - You can also request for a feature [here](https://github.com/dojoengine/dojo-starter/issues), and if it's viable, it will be picked for development.

3. **Create a Pull Request**
    - It can't get better then this, your pull request will be appreciated by the community.

Happy coding!
