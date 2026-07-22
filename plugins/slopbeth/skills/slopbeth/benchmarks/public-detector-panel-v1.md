# Public detector panel v1

Date: 2026-06-18

This panel is weak evidence. It records what public tools returned on dated samples. It does not prove a passage is human, safe, or permanently undetectable.

## Panel summary

| Tool | Current result rows | Result classes observed |
| --- | ---: | --- |
| QuillBot AI Detector | 3 | human, mixed |
| Sapling AI Content Detector | 5 | ai |
| ZeroGPT | 4 | human, mixed |

## Sample coverage

| Sample | Category | Length | Detector disagreement |
| --- | --- | --- | --- |
| `ctrl-med-001` | human control | medium | yes |
| `essay-long-001` | essay | long | yes |
| `mkt-001` | marketing | short | yes |
| `tech-long-001` | technical policy | long | yes |
| `email-008` | support email | short | no stable panel result |

## Finding

The same polished outputs received conflicting detector labels. One detector also flagged the human-control sample. That makes public detectors useful as regression sensors, but not as a release target.

## Use in Slopbeth

- Record the tool and its limitation.
- Treat detector disagreement as expected evidence.
- Never rewrite text to please a detector if that edit weakens truth or voice.
- Never claim detector immunity from this panel.
