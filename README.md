This API server is designed to simplify various ENS-related queries, including:

- Resolving ENS to address
- Resolving address to ENS
- Resolving NFT avatar URL if set
- Getting the content hash URL if set

## Build and Run

After cloning the repo, run the following commands to build and run the server:

```bash
brew install vapor
vapor build
vapor run serve
```

And it will be running on http://localhost:8080

If you want the server to listen on all interfaces and a different port, run the following command:

```bash
vapor run serve --hostname 0.0.0.0 --port 8123
```

## Live Demo

* ENS domain with IPNS content hash: https://api.planetable.xyz/ens/resolve/planetable.eth
* ENS domain with a Juciebox Project ID: https://api.planetable.xyz/ens/resolve/jango.eth