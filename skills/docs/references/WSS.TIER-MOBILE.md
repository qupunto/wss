# T4 — Client: mobile

Loaded on demand from `WSS.TAXONOMY.md`. Read this when the project has a mobile app; skip it
entirely otherwise.

| Page | Covers | When |
|---|---|---|
| `mobile/WSS.OVERVIEW.md` | Native vs cross-platform choice, project layout, per-platform toolchain and minimum OS versions | Any mobile app |
| `mobile/navigation.md` | Navigation graph, deep links, universal/app links, back-stack behavior | Always |
| `mobile/offline.md` | Local persistence, sync strategy, conflict resolution, queued mutations | The app works offline at all |
| `mobile/platform.md` | Permissions and their rationale strings, camera/location/biometrics, background execution limits | Any native capability used |
| `mobile/push.md` | Notification setup per platform, token lifecycle, payload contract, deep-link targets | Push present |
| `mobile/release.md` | Signing and provisioning, store metadata, review requirements, staged rollout, forced upgrade | Always — this is the tier's biggest knowledge sink |
| `mobile/performance.md` | Startup time, bundle/app size budgets, list virtualization, memory on low-end devices | Perf is a stated concern |

Note `mobile/release.md` separately from `T8 deploy.md`: app stores impose review latency,
signing identity, and version-pinning problems that server deploys simply do not have.

**When mobile is the only surface**, drop the `mobile/` prefix entirely (`WSS.TAXONOMY.md`'s
promotion rule) and fold `mobile/WSS.OVERVIEW.md` into T1's `WSS.OVERVIEW.md` — for a mobile-only repo they are
the same page, and keeping both forces the reader to look in two places for the toolchain. The
same folding applies to any single-surface project: a web-only repo has no `client/` prefix.
