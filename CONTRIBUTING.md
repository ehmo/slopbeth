# Contributing

Slopbeth improves through small, public examples.

## useful reports

Open an issue when you can share:

- the source text
- the Slopbeth output
- the exact fact, obligation, uncertainty, or voice that changed
- the output you expected
- whether the case is a bad rewrite or a false positive

Keep examples public. Do not include private customer data, secrets, contracts, medical records, legal records, or unpublished personal material.

## pull requests

Pull requests should be narrow:

- one behavior change per pull request
- one benchmark case for each new failure mode
- no detector-immunity claims
- no copied competitor wording or examples
- no generated contributor attribution

Run before opening a pull request:

```bash
npm test
python3 scripts/attribution_scan.py
python3 scripts/ci_secret_scan.py
npm pack --dry-run
```

## benchmark cases

Good cases are small and checkable. Include the source, required facts, forbidden output terms, and expected edit depth.

Use `benchmarks/false-positive-tracker-v1.jsonl` when Slopbeth should leave a sentence alone or edit it lightly.
