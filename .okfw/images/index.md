# images

<!-- okfw:generated — maintained by okfw; edits here are overwritten -->

## Concepts

* [Images overview](images-overview--01a1837da526.md) - One concept for each image in versions.json: what it is, its track, its trust class, and its open issues and waivers.
* [dapr-placement](dapr-placement--01a183832e48.md) - The Dapr placement service for actors, built from the pinned Dapr source onto ubi9-micro in lockstep with daprd and dapr-scheduler.
* [dapr-scheduler](dapr-scheduler--01a183832e6e.md) - The Dapr scheduler, which keeps actor reminders and workflow state in embedded etcd, built from the pinned Dapr source onto ubi9-micro.
* [daprd](daprd--01a183832e23.md) - The Dapr sidecar, built with all components from the pinned Dapr source onto ubi9-micro in lockstep with the two Dapr control-plane images.
* [hydra](hydra--01a183832d9f.md) - Ory Hydra, the OAuth 2.0 and OpenID Connect server, built from the pinned Ory source onto ubi9-micro in lockstep with the Ory images.
* [keto](keto--01a183832dc0.md) - Ory Keto, the permission server, built CGO-free from the pinned Ory source onto ubi9-micro in lockstep with the Ory images.
* [kratos](kratos--01a183832d7f.md) - Ory Kratos, the identity server, built from the pinned Ory source onto ubi9-micro in lockstep with the other three Ory images.
* [loki](loki--01a183832eba.md) - The Grafana Loki log store with the logcli client, built from source onto ubi9-micro; it joined in observe mode.
* [mssql](mssql--01a183832d44.md) - Microsoft SQL Server 2025 on RHEL 10, mirrored from MCR for amd64 only and verified with its Notary Project signature; trust class notation.
* [nats](nats--01a183832e00.md) - The NATS messaging server with JetStream, built from source onto ubi9-micro with our own config and the strongest binary cross-check anchor.
* [nexus3](nexus3--01a183832d26.md) - The Sonatype Nexus 3 repository manager, mirrored from Docker Hub on the 3.90 patch line with no verifiable signature; trust class none.
* [oathkeeper](oathkeeper--01a183832de0.md) - Ory Oathkeeper, the identity and access proxy, built from the pinned Ory source onto ubi9-micro in lockstep with the Ory images.
* [postgres](postgres--01a183832d06.md) - The PostgreSQL database, mirrored from Docker Hardened Images in four variants for majors 16 and 17; trust class dhi.
* [prometheus](prometheus--01a183832e94.md) - The Prometheus monitoring server with promtool and the prebuilt web UI of the vendor, built from source onto ubi9-micro.
* [prometheus-nats-exporter](prometheus-nats-exporter--01a183832f0f.md) - The Prometheus exporter for NATS monitoring endpoints, built from source onto ubi9-micro; PR #29 is the reason for the observe-is-not-a-pass rule.
* [seaweedfs](seaweedfs--01a183832ee2.md) - The SeaweedFS object store with an S3 gateway, the replacement for MinIO, built from source onto ubi9-micro; it joined in observe mode.
* [traefik](traefik--01a183832cbc.md) - The traefik reverse proxy, mirrored from Docker Hardened Images with its DHI signature and attestations; trust class dhi.
* [whoami](whoami--01a183832d61.md) - The traefik whoami echo server, a test backend, mirrored from Docker Hub on three platforms with no signature to verify; trust class none.

