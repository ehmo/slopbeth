# Creation and Validation

Slopbeth was built by benchmark-driven iteration, not by training a model.

The workflow used:

- benchmark research on detector credibility and writing evaluation
- a fixed anti-slop taxonomy
- source-locked rewrite rules
- hidden-gold forward tests
- red, green, and refactor judge rows
- semantic-drift checks
- unsummarizability checks
- detector-panel records
- clean-room similarity scans
- RAID smoke validation on `omarchy`
- public repo, issue, and pull request review for benchmark ideas
- academic and writing-craft literature review

The shipped public gate is `node bin/slopbeth.js benchmark`. It checks the v1 prompt pack and runs the v2 output-bearing corpus through preservation, semantic-drift, signature, and unsummarizability checks.

The detector-immunity gate was rejected as a release target because public detectors disagreed and one detector flagged a human-control sample. That result shaped the final rule: detectors are weak regression evidence, not the definition of good writing.

The release target is narrower and more useful:

- fewer generic claims
- less filler
- stronger source preservation
- denser prose
- fewer unsupported edits
- clear benchmark artifacts

The public package includes the current competitor matrix in `benchmarks/competitor-matrix-v2.md` and the research basis in `docs/literature-basis.md`.
