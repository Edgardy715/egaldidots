# Legacy pet code (archived 2026-10-23)

The first Eshell Pets runtime (ghost/blob/octopus drawn with Shapes, one
PetHost per surface) and its fixtures, moved here when the Mimo perch runtime
replaced it (see `docs/eshell-pets-redesign-2026-10-23/`). Kept for reference
and for before/after comparisons; nothing in `bar/` imports these files.

Measured with the same frameSwapped harness before archiving
(`docs/eshell-pets-redesign-2026-10-23/perf/before-isolated-swap/`): the old pet
presented 195 fps while reacting and 240 fps (vsync) while sleeping, at
8.3% and 9.4–9.7% of one core.

The paths mirror the original tree. To run them again they would need the old
`pets` settings schema and the old `bar/pets` directory without its qmldir.
