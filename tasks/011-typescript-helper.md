# 011: The TypeScript helper

Status: todo

Settle the open question in the architecture doc: a `.ts` file typed to the subset that
writes `api.json`.

## Acceptance criteria

- [ ] Decided whether it lives here or in its own repository, recorded with the reason
- [ ] If kept: its types describe the subset exactly, and `tsc` rejects every construct
      task 003's generator rejects, checked by a test of each
- [ ] Decided whether it exports from valibot, with the lossy cases listed
