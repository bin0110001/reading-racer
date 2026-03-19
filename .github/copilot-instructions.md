After updating a GDScript file, run the repository helper script to parse, lint, check formatting, and validate with Godot all at once.

1) Install or update the gdtoolkit CLI:

python -m pip install -U gdtoolkit

2) Run the check script (recommended):

```powershell
# From the repository root
powershell -ExecutionPolicy Bypass -File .\tools\gdscript-check.ps1
```

This will:
- Run gdparse to check syntax
- Run gdlint to check code style
- Run gdformat to check formatting
- Run Godot validation (--headless --script --check-only) to catch strict parser errors

3) (Optional) Auto-format all scripts:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\gdscript-check.ps1 -Fix
```
