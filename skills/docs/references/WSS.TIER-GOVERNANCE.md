# T10 — Governance

Loaded on demand from `WSS.TAXONOMY.md`. Read this only when a compliance, legal, or
organizational obligation actually applies to the project.

Does not replace review by counsel or an auditor.

**Commonly applicable**

| Page | Covers | When |
|---|---|---|
| `governance/privacy.md` | Personal-data inventory and lawful basis per field, retention and deletion, subject-request handling, processors and sub-processors, cross-border transfers, DPIA outcome, breach-notification path | Any personal data (GDPR/UK GDPR, CCPA/CPRA, LGPD) |
| `governance/accessibility.md` | Target standard and level, conformance status, known exceptions with remediation dates, evaluation method, feedback channel | Public sector or consumer-facing in a regulated market (WCAG 2.2, EN 301 549, EAA) |
| `governance/licensing.md` | Project license, dependency license inventory and compatibility, attribution obligations, SBOM location and format | Always — non-negotiable if anything ships to a third party |
| `governance/audit-trail.md` | What is logged, immutability guarantees, retention, who may read it, tamper evidence | Actions must be attributable after the fact |
| `governance/data-governance.md` | Data classification, ownership per dataset, residency constraints, access-review cadence | Data crosses teams or jurisdictions |

**Sector-specific** — one page per framework in scope, each mapping controls to where they
are implemented and where evidence is produced:

| Framework | Typical documentation obligation |
|---|---|
| ISO/IEC 27001, SOC 2 | Control-to-implementation mapping, risk register pointer, evidence-collection procedure |
| PCI DSS | Cardholder-data flow diagram, scope boundary and segmentation, SAQ type |
| HIPAA | PHI inventory, BAAs, minimum-necessary access design, audit-control implementation |
| GxP — GLP/GMP/GCP | Computerised system validation approach (GAMP 5 category), URS/IQ/OQ/PQ traceability, change-control procedure |
| FDA 21 CFR Part 11 / EU Annex 11 | Electronic-record integrity, e-signature binding, audit-trail specification, system-access controls |
| EU AI Act | System classification, technical documentation set, data-governance and human-oversight measures, logging |
| EU CRA / SBOM mandates | SBOM generation in CI, vulnerability-handling and disclosure policy, support window |
| DORA, PSD2/SCA | ICT risk and third-party register, SCA flow documentation, incident-reporting path |
| IEC 62304 / MDR | Software safety classification, architecture and unit traceability, risk-management file linkage |
| ENS (RD 311/2022, ES public sector) | Security category, control-set applicability, self-assessment or certification evidence |

The pattern for every one of these: **state the obligation, point at the implementation,
point at the evidence.** Do not restate the regulation — the auditor already has it. What
they lack is the map from control to code.
